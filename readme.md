# NTSG Backup Scripts

> [!WARNING]
> Archived and no longer maintained; kept for reference. Written in 2016. The prebuilt binaries in `bin/` bundle 2016 copies of jq and 7-Zip (16.02), so don't run them as-is.

- [NTSG Backup Scripts](#ntsg-backup-scripts)
  - [Overview](#overview)
    - [What it does](#what-it-does)
  - [Using it](#using-it)
    - [Builds](#builds)
    - [User config JSON file](#user-config-json-file)
    - [Windows version](#windows-version)
    - [Linux version](#linux-version)
  - [Credits](#credits)

## Overview

A pair of backup scripts, one for Linux and one for Windows, that copy only the kinds of files you ask for (documents, source code, raw data, and so on), compress the copy, and log what happened.

I wrote these in the fall of 2016 as the Linux sysadmin for NTSG, a research group at the University of Montana. Researchers needed a simple way to back up the files that mattered without learning rsync or Robocopy filter syntax.

**Tech:** Bash, Windows batch, rsync, Robocopy, jq, tar, 7-Zip, Makeself, Bat To Exe Converter

### What it does

- Copies only the file types in one section of `user_config.json` (`documents`, `source_code`, `raw_data`, or one you add), turned into rsync `--include` rules or Robocopy file patterns
- Skips files that haven't changed since the last backup
- Compresses the copy with tar or 7-Zip and writes a timestamped log
- Ships as self-contained builds with jq (and 7-Zip on Windows) inside: a Makeself `.run` file on Linux, and 32- and 64-bit `.exe` files on Windows

## Using it

### Builds

Prebuilt copies are in `bin/`, each with its own readme:

- `bin/linux/x64/ntsg_backup.run`: a [Makeself](https://makeself.io/) archive with the script and jq. 64-bit only. Paths must be absolute when you run the `.run` file directly. See [bin/linux/readme.md](bin/linux/readme.md) for Makeself's extra flags (`--keep`, `--noexec`, `--target`, …).
- `bin/windows/x64/ntsg_backup_x64.exe` and `bin/windows/x86/ntsg_backup_x86.exe`: built with [Bat To Exe Converter](https://www.f2ko.de/en/applications/bat-to-exe-converter/), with jq and 7-Zip inside. The 32-bit version may crash when compressing directories over about 5 GB. See [bin/windows/readme.md](bin/windows/readme.md).

To run from source on Linux, use `linux/ntsg_backup.sh`; jq is included in `linux/lib/jq/`. To run `windows/ntsg_backup.cmd` from source, you'll need to add `jq.exe` and `7za.exe` under `windows/lib/jq/x64/` and `windows/lib/7zip/x64/`, since only their license and readme files are committed.

### User config JSON file

#### Overview

The `user_config.json` file is used by the Linux and Windows versions of the script, and they each have their own copy in `linux` and `windows` folders.

The default `user_config.json` file for Linux looks something like this:

```json
{
	"compression":
	{
		"compress_after_copy": "true",
		"compress_type": "bzip",
		"backup_name": "ntsg-rsync"
	},
	"file_types":
	{
		"documents":
		[
			"*.pdf",
			"*.doc",
			"*.docx",
			"*.ppt",
			"*.pptx",
			"*.txt",
			"*.md"
		],
		"source_code":
		[
			"*.c",
			"*.h",
			"*.cpp",
			"*.hpp",
			"*.py",
			"*.v",
			"*.mat"
		],
		"compressed_data":
		[
			"*.zip",
			"*.tar",
			"*.gz",
			"*.h5",
			"*.hdf"
		],
		"raw_data":
		[
			"*.tif",
			"*.bin",
			"*.dat",
			"*.csv",
			"*.img"
		],
		"everything":
		[
			"*.*"
		]
	}
}
```

#### Compression

The entries under the `compression` object describe variables that are used during the compression phase of the backup. During this phase, it will compress the directory the script created in the beginning into a compressed file and then delete the uncompressed directory.

Note that the variables `compress_type` and `backup_name` will not be used if `compress_after_copy` is false.

##### Windows Compression Types

- 7z
- zip
- tar

##### Linux Compression Types

- gzip
- bzip

#### File Types

The entries under the `file_types` object represent filename patterns that the script will use to selectively copy files that match everything under that file type section name. File type section names are very configurable and the script will not break if you delete one, rename one, add more filename patterns to another, etc. The only caveat is that you need to ensure there is *at least one* file type section name with filename wildcards under `file_types`.

WARNING: Use the `everything` file type section name with caution because *you will be copying everything*. This will tie up the I/O bus and may force the machine you ran this script on to slow to a crawl.

##### New file type example

Suppose that you prefixed a project's documentation with "IMPORTANT-PROJECT-DOCS_". You can easily create a file type section name that captures this precious documentation, and it would look something like this:

```json
{
	"file_types":
	{
    	"project-docs":
        [
        	"IMPORTANT-PROJECT-DOCS_*"
        ]
    }
}
```



### Windows version

#### Overview

The Windows version of this script is written as a DOS-style batch file that uses *Robocopy* (built-in to most Windows machines) to copy files from an input path to an output path. It also uses *jq* (a library that is bundled in this script) to parse the `user_config.json` file so you can easily pass in what types of files to copy. If enabled, it also uses a bundled portable version of *7zip* to compress the backup at the end.

#### Usage

```
ntsg_backup.exe <user config> <logs> <input> <output> <file type section name> [robocopy options]
```

| Argument Name         |Required?| Description                                                                 |
|-------------------------|-----|-------------------------------------------------------------------------------|
| user config             | Yes | The path to the JSON config file                                              |
| logs                    | Yes | The path to output the logs; it does not need to exist                        |
| input                   | Yes | The path to copy from; it needs to exist                                      |
| output                  | Yes | The path to copy to; it needs to exist                                        |
| file type section name  | Yes | The name of the section from user_config.json for filtering the files to copy |
| robocopy options        | No  | [Options for the robocopy command](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy)  |


#### Examples

For these examples, let's say that we want to back up a folder in a network-mapped drive to a folder on my C drive. The paths of these two folders look something like this:

- `W:\TRANS\adm_angela`
- `C:\Backups`

The logs will go in:

- `C:\Logs`

The user config file is at:

- `C:\user_config.json`

##### File type section name usage

If I wanted to backup *everything*, then a basic example of using this script looks like the following:

```bash
ntsg_backup.exe "C:\user_config.json" "C:\Logs" "W:\TRANS\adm_angela" "C:\Backups" "everything"
```

If I wanted to backup only *source code*, then it would look like this:

```bash
ntsg_backup.exe "C:\user_config.json" "C:\Logs" "W:\TRANS\adm_angela" "C:\Backups" "source_code"
```

##### Robocopy options usage

The default value for `[robocopy options]` is `/S /XO /NDL`.

| Name     | Description                                                                     |
| -------- | ------------------------------------------------------------------------------- |
| `/S`     | Copy non-empty subdirectories                                                   |
| `/XO`    | Skip copying files that are older (i.e. no changes since last backup)           |
| `/NDL`   | Do not log directory names                                                      |

There are a ton more options, and you can find documentation for these options at the [Microsoft Robocopy docs](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy).

If you wanted to, for example, still have the `/S /XO /NDL` options but also wanted the `/Z` restartable mode option (allows you to pick up where you left off if robocopy was interrupted), you would do the following:

```bash
ntsg_backup.exe "C:\user_config.json" "C:\Logs" "W:\TRANS\adm_angela" "C:\Backups" "everything" "/S /XO /NDL /Z"
```

#### Logging

The output for the execution of the script will automatically go into a time-stamped file in the `logs` directory. It will look something like this:

```
// C:\Logs\adm-angela__backup-everything_2016-09-20_17-21-13.log

===============================================================
 [2016/09/20 15:21:13]: BEGIN ROBOCOPY. Please wait...
===============================================================

-------------------------------------------------------------------------------
   ROBOCOPY     ::     Robust File Copy for Windows
-------------------------------------------------------------------------------

  Started : Tuesday, September 20, 2016 5:21:33 PM
   Source : W:\TRANS\adm_angela\
     Dest : C:\Backups\

    Files : *.*

  Options : *.* /NDL /TEE /S /DCOPY:DA /COPY:DAT /ETA /XO /R:1000000 /W:30
  ...
------------------------------------------------------------------------------

               Total    Copied   Skipped  Mismatch    FAILED    Extras
    Dirs :       542       538         4         0         0         0
   Files :        14         0        14         0         0         0
   Bytes :    62.7 k         0    62.7 k         0         0         0
   Times :   0:00:09   0:00:00                       0:00:00   0:00:09
   Ended : Tuesday, September 20, 2016 5:21:42 PM

===============================================================
 [2016/09/20 15:21:42]: END ROBOCOPY.
===============================================================
===============================================================
 [2016/09/20 15:21:42]: BEGIN 7ZIP. Please wait...
===============================================================

7-Zip (a) [32] 16.02 : Copyright (c) 1999-2016 Igor Pavlov : 2016-05-21

Scanning the drive:
1 folder, 8 files, 8731965 bytes (8528 KiB)

Creating archive: C:\Backups\adm-angela__backup-everything_2016-09-20_17-21-13.7z

Items to compress: 9


Files read from disk: 8
Archive size: 7450676 bytes (7277 KiB)
Everything is Ok
===============================================================
 [2016/09/20 15:22:01] END 7ZIP.
===============================================================
===============================================================
 [2016/09/20 15:22:01]: Removing output directory. Please wait...
===============================================================
===============================================================
 [2016/09/20 15:22:05]: Done removing output directory.
===============================================================
```

Note that the name of the log (shown as a comment at the top) also includes the file type section name. In this case, the file type section name was `everything`. We know this because the log file name is of the form `<backup_name>__backup-<file_type_section_name>_<datetime>.log`. Also note that, if `compress_after_copy` is false, `<backup_name>` will be a default value and ignore the `backup_name` entry in `user_config.json`.

### Linux version

#### Overview

The Linux version of this script is written as a bash style script that uses *Rsync* (built-in to most Linux machines) to copy files from an input path to an output path. It also uses *jq* (a library that is bundled in this script) to parse the `user_config.json` file so you can easily pass in what types of files to copy. If enabled, it also uses *Tar* to compress the backup at the end.

#### Usage

```
ntsg_backup.run <user_config> <logs> <input> <output> <file type section name> [rsync options]
```

| Argument Name         |Required?| Description                                                                 |
|-------------------------|-----|-------------------------------------------------------------------------------|
| user config             | Yes | The path to the JSON config file                                              |
| logs                    | Yes | The path to output the logs; it does not need to exist                        |
| input                   | Yes | The path to copy from; it needs to exist                                      |
| output                  | Yes | The path to copy to; it needs to exist                                        |
| file type section name  | Yes | The name of the section from user_config.json for filtering the files to copy |
| rsync options           | No  | [Options for the rsync command](https://www.computerhope.com/unix/rsync.htm)   |



#### Examples

For these examples, let's say that we want to back up a folder on a mounted share to a backups folder on the same share. The paths of these two folders look something like this:

- `/anx_v4/TRANS/adm_angela`
- `/anx_v4/backups`

The logs will go in:

- `/logs`

The user config file is at:

- `/user_config.json`

##### File type section name usage

If I wanted to backup *everything*, then a basic example of using this script looks like the following:

```bash
./ntsg_backup.run "/user_config.json" "/logs" "/anx_v4/TRANS/adm_angela" "/anx_v4/backups" "everything"
```

If I wanted to backup only *source code*, then it would look like this:

```bash
./ntsg_backup.run "/user_config.json" "/logs" "/anx_v4/TRANS/adm_angela" "/anx_v4/backups" "source_code"
```

##### Rsync options usage

The default value for `[rsync options]` is `-auvm`.

| Name                    | Description                                                                     |
| ----------------------- | ------------------------------------------------------------------------------- |
| `-a,--archive`          | Archive mode; equals -rlptgoD                                                   |
| `-u,--update`           | Skip files that are newer on the receiver							            |
| `-v,--verbose`          | Increase verbosity		                                                        |
| `-m,--prune-empty-dirs` | Prune empty directory chains from file list                                     |

There are a ton more options, and you can find documentation for these options at the [Computerhope Rsync Docs](https://www.computerhope.com/unix/rsync.htm).

If you wanted to, for example, still have the `-aum` options but did not want rsync verbosity, you would do the following:

```bash
./ntsg_backup.run "/user_config.json" "/logs" "/anx_v4/TRANS/adm_angela" "/anx_v4/Backups" "everything" "-aum"
```

#### Logging

The output for the execution of the script will automatically go into a time-stamped file in the `logs` directory. It will look something like this:

```
// /logs/adm-angela__backup-documents_2016-09-27_16-10-27.log

===============================================================
[2016/09/27 16:10:27] RSYNC BEGIN. Please wait....
===============================================================
2016/09/27 16:10:27 [16644] building file list
2016/09/27 16:10:28 [16644] done
2016/09/27 16:10:28 [16644] created directory /anx_v4/backups/adm-angela__backup-documents_2016-09-27_16-10-27
...
===============================================================
[2016/09/27 16:10:29] RSYNC END.
===============================================================
===============================================================
[2016/09/27 16:10:29] TAR BEGIN. Please wait...
===============================================================
...
===============================================================
[2016/09/27 16:10:32] TAR END.
===============================================================
===============================================================
[2016/09/27 16:10:32] Removing output directory. Please wait...
===============================================================
===============================================================
[2016/09/27 16:10:32] Done removing output directory.
===============================================================

```

Note that the name of the log (shown as a comment at the top) also includes the file type section name. In this case, the file type section name was `documents`. We know this because the log file name is of the form `<backup_name>__backup-<file_type_section_name>_<datetime>.log`. Also note that, if `compress_after_copy` is false, `<backup_name>` will be a default value and ignore the `backup_name` entry in `user_config.json`.

## Credits

- Application icon by [Round Icons](https://www.flaticon.com/authors/roundicons) from Flaticon
- Bundled: [jq](https://jqlang.github.io/jq/) and [7-Zip](https://www.7-zip.org/) (license files in `linux/lib/` and `windows/lib/`)
