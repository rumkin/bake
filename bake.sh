#!/bin/bash

set -e

BAKEEXE=$(readlink -f $0)

BAKE_VERSION=0.15.1
BAKE_FILE=${BAKE_FILE:-bake.sh}

# Split string (arg #2) into array by separator (arg #1)
split() {
    local IFS=$1
    set -f
    local arr=($2)
    set +f
    printf '%s\n' "${arr[@]}"
}

# Search file (arg #2) up the path (arg #1).
bake:lookup() {
    local D=${1:-.}
    local FILENAME=$2
    arr=($(split "/" $D))

    for i in $(seq `expr ${#arr[@]} - 1` -1 0)
    do
        DIR="/"
        FOUND=""
        for n in `seq 0 $i`
        do
            DIR=${DIR}${arr[$n]}/
        done
        FILE=${DIR}${FILENAME}
        if [ -f "$FILE" ]
        then
            echo $FILE
            break
        fi
    done
}

BAKERC=`bake:lookup $PWD ".bakerc"`

if [ -n "$BAKERC" ] && [ -f "$BAKERC" ]
then
    BAKE_DIR=`dirname $BAKERC`

    . "$BAKERC"
fi

case $1 in
    -v)
        echo $BAKE_VERSION
        exit
    ;;
    -h)
        {
          echo "Usage is $0 [OPTIONS] <TASK>"
          echo "Options:"
          echo -e "\t-l – List tasks from bakefile"
          echo -e "\t-e [ENV] [TASK] – Specify environment name. Output environment"
          echo -e "\t-i <MODULE> – Install module from github or bitbucket"
          echo -e "\t-v – Output bake version"
          echo -e "\t-h – Show this help"
        } >&2
        exit 1
    ;;
esac

if [ $# -lt 1 ]; then
    exit
fi

task:bake:init() {
    [ ! -f "$BAKE_FILE" ] && touch $BAKE_FILE
    [ ! -d "bake_modules" ] && mkdir bake_modules
}

bake:install_module() {
  local URL=$1
  local MODULE=$URL

  if bake:starts_with "https://" "$MODULE"
  then
    MODULE=`bake:cut_start "https://" "$MODULE"`
  elif bake:starts_with "http://" "$MODULE"
  then
    MODULE=`bake:cut_start "http://" "$MODULE"`
  fi


  if bake:starts_with "github.com" "$MODULE" || bake:starts_with "bitbucket.org" "$MODULE"
  then
    local MODULE_PATH=bake_modules/$MODULE
    local TMP=`mktemp -d`
    git clone "https://$MODULE" "$TMP"
    mkdir -p "$(dirname $MODULE_PATH)"
    [ -e "$MODULE_PATH" ] && rm -rf "$MODULE_PATH"
    mv "$TMP" "$MODULE_PATH"
  elif bake:egrep_match '^\.{0,2}/' "$MODULE"
  then
    local MODULE_PATH=bake_modules/$(basename $MODULE)
    # TODO remove with backup and restore on failure...
    [ -e "$MODULE_PATH" ] && rm -rf "$MODULE_PATH"
    cp -r "$MODULE" "$MODULE_PATH"
  else
    echo "Unknown module type" >&2
    exit 1
  fi
}

bake:starts_with() {
  local PREFIX=$1
  local STR=$2
  local PREFLEN=${#PREFIX}
  if [ "${STR:0:$PREFLEN}" = "$PREFIX" ]
  then
    return 0
  else
    return 1
  fi
}

bake:cut_start() {
  local PREFIX=$1
  local STR=$2
  local PREFLEN=${#PREFIX}

  echo ${STR:$PREFLEN}
}

bake:egrep_match() {
  if echo "$2" | egrep "$1" 1>/dev/null
  then
    return 0
  else
    return 1
  fi
}

bake:cut_end() {
  local PREFIX=$1
  local STR=$2
  local PREFLEN=${#PREFIX}

  echo ${STR:0:-$PREFLEN}
}

bake:module() {
    local BAKE_MODULE=`bake:lookup "$BAKE_DIR" "bake_modules/$1/module.sh"`

    # TODO Add loaded modules index to avoid duplications and collisions.

    if [ -z "$BAKE_MODULE" ]
    then
        echo "Bake module $1 not found"
        exit 1
    fi

    . $BAKE_MODULE
}

bake:require_bakefile() {
  if [ ! -f $1 ]
  then
    echo "Bakefile $1 not found" >&2
    exit 1
  fi

  . $1
}

bake:func_exists() {
    type $1 2>/dev/null | grep -q "is a function"
}

bake:task() {
  local BAKE_TASK=$1

  shift 1

  if bake:func_exists task:$BAKE_TASK
  then
    CWD=$PWD
    cd $BAKE_DIR
    task:$BAKE_TASK "$@"
  else
    echo "Task '$BAKE_TASK' is not defined" >&2
    exit 1
  fi
}

if [ -z "$BAKE_DIR" ]
then
    TMP_BAKE_FILE=`bake:lookup $PWD $BAKE_FILE`
    if [ -n "$TMP_BAKE_FILE" ]
    then
        BAKE_FILE=$TMP_BAKE_FILE
        BAKE_DIR=`dirname $BAKE_FILE`
    else
        BAKE_DIR=$PWD
    fi
    unset TMP_BAKE_FILE
else
    BAKE_FILE=$BAKE_DIR/$BAKE_FILE
fi

if [ "${1:0:1}" = "-" ] && [ ${#1} = 2 ]
then
    case $1 in
        "-i") # install module
          bake:install_module $2
          exit 0;
          ;;
        "-l") # List used defined tasks

            bake:require_bakefile $BAKE_FILE
            FUNCTIONS=`declare -F | awk '{ print $3 }'`
            for FUNC in $FUNCTIONS
            do
                if [ ${FUNC:0:5} = "task:" ]
                then
                    LENGTH=`expr ${#FUNC} - 5`
                    NAME=`echo ${FUNC:5:$LENGTH} | sed 's/_/-/g'`
                    echo $NAME
                fi
            done
            exit 0;

            ;;
        "-e") # set bake environment
            if [ -z "$2" ]
            then
                if [ -e "${BAKE_DIR}/.env" ]
                then
                  cat "${BAKE_ENV}/.env"
                  exit 0
                fi
            fi

            BAKE_ENV=$2
            BAKE_ENV_FILE=${BAKE_DIR}/bake_env/${BAKE_ENV}.sh
            shift 2

            if [ ! -e "${BAKE_ENV_FILE}" ]
            then
                echo "Environment file '${BAKE_ENV}' not found"
                exit 1
            fi

            if [ $# -eq 0 ]
            then
              if [ -e "${BAKE_DIR}/.env" ]
              then
                rm "${BAKE_DIR}/.env";
              fi

              ln -s "${BAKE_ENV_FILE}" "${BAKE_DIR}/.env"
              exit 0
            fi
            ;;
        ?) echo "Unknown flag $1"
            exit 1;
        ;;
    esac
fi

BAKE_TASK=$(echo $1 | sed 's/-/_/g')
shift 1

if [ -n "${BAKE_ENV_FILE}" ]
then
    . $BAKE_ENV_FILE
elif [ -e "${BAKE_DIR}/.env" ]
then
    . "${BAKE_DIR}/.env"
fi

if [ -f "${BAKE_FILE}" ]
then
  . "$BAKE_FILE"
fi

bake:task $BAKE_TASK "$@"
