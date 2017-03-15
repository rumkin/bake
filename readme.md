# Bake

Bake is a modular task running tool written on pure bash.

## Usage

All you need is to create `bake.sh` into root of your project. Run `bake bake:init`
command. It will create empty `bake.sh` file and `bake_modules` directory.

Example bakefile:

```bash
# bake.sh

# Initialize new node package
task:hello() {
    echo 'Hello'
}

task:say_hello() {
    echo 'Hello again'
}
```

Now you can run tasks:

```shell
bake hello # -> Hello
bake say-hello # -> Hello again
```

## Modules

Modules are simple shell files stored in directory `bake_modules`. Module
could be required with command `bake:module`. It could contain tasks and custom
functions or variables.

Example:
```bash
# bake_modules/hello_world.sh
hello_world:print() {
  echo "Hello world"
}

# bake.sh
bake:module hello_world
task:run() {
    hello_world:print # -> Hello world
}
```

## CLI arguments

* -l – List tasks.
* -v – Print bake version.
* -h – Print bake help.
* -e [environment] – Specify environment file `bake_${environment}.sh`.

## Lookup and $PWD

Bake by default looking up the directory tree and search for `.bakerc` then `bake.sh`
file. After that bake switch `$PWD` to the project's root. Calling directory will be stored in `$CWD` variable.

Example:

```bash
# example/bake.sh
task:pwd() {
    echo $PWD $CWD
}

task:ls() {
    ls .
}
```

```bash
cd example/nest
bake pwd # -> example example/nest
bake ls # -> bake.sh nest
```

## Environment

Environments store in `bake_env` directory in shell files like `dev.sh`. Current
environment lays at `.env` file. To dump current environment run `bake -e`. To
switch environment run `bake -e <env>`. To use environment in current
call run `bake -e <env> <task>`.

## License

MIT.
