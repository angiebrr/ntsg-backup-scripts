# NTSG Backup Scripts: Linux Build v1.0.0

## Overview

Although written in bash, the Linux versions have been archived as a "run" file that will uncompress itself and include the libraries that are needed to run it. There is only a 64-bit version of the program.

You only need the run file, but you can download the `user_config.json.example` as a reference for what the program is expecting.

## Special Commands 

The "run" file is an archives generated with Makeself and, as such, can be passed the following additional arguments:

* `--keep` : Prevent the files to be extracted in a temporary directory that will be removed after the embedded script's execution. The files will then be extracted in the current working directory and will stay here until you remove them.
* `--verbose` : Will prompt the user before executing the embedded command
* `--target <dir>` : Allows to extract the archive in an arbitrary place.
* `--nox11` : Do not spawn a X11 terminal.
* `--confirm` : Prompt the user for confirmation before running the embedded command.
* `--info` : Print out general information about the archive (does not extract).
* `--lsm` : Print out the LSM entry, if it is present.
* `--list` : List the files in the archive.
* `--check` : Check the archive for integrity using the embedded checksums. Does not extract the archive.
* `--nochown` : By default, a "chown -R" command is run on the target directory after extraction, so that all files belong to the current user. This is mostly needed if you are running as root, as tar will then try to recreate the initial user ownerships. You may disable this behavior with this flag.
* `--tar` : Run the tar command on the contents of the archive, using the following arguments as parameter for the command.
* `--noexec` : Do not run the embedded script after extraction.

Any subsequent arguments to the archive will be passed as additional arguments to the embedded command. You should explicitly use the -- special command- line construct before any such options to make sure that Makeself will not try to interpret them.

## Known Issues

- There is only a 64-bit version
- Paths MUST be absolute if you are only using the "run" file. If you use the `--keep` and `--noexec` commands and run the `ntsg_backup.sh` script directly, then the path does not need to be absolute.




-------------------------------------------------------------------


__Author:__ Angela Gross

__Building Tool__: Built by [Makeself](http://stephanepeter.com/makeself/) from stephanepeter.com

__Created Date:__ 09/30/2016

__Recommended Viewer:__ [Horoopad: Cross Platform Markdown Editor](https://github.com/rhiokim/haroopad) or Bitbucket/Github