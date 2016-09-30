@ECHO OFF
SETLOCAL
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION

IF ["%b2eincfilecount%"]==[""] (SET me=%~n0 && SET parent=%~dp0) ELSE (SET me=%b2eprogramname% && SET parent=%b2eprogrampathname%)

:: =======================================================================
:: ntsg_backup.cmd
:: -----------------------------------------------------------------------
:: NTSG Backup Solution
:: Angela Gross
:: 09/2016
:: -----------------------------------------------------------------------
:: Uses robocopy, jq, and 7zip to backup and compress categories of files
:: =======================================================================

:: ///////////////////////////////////////////////////////////////////////

:: ----------------------------------------------------------------------
:: IMPORTANT VARS
:: ----------------------------------------------------------------------

:: Set executables depending on if it's a compiled exe. If it's not, 
:: assume that it's a dev environment on a 64 bit computer
IF ["%b2eincfilecount%"]==[""] (
	SET seven_zip=%parent%lib\7zip\x64\7za.exe
	SET jq=%parent%lib\jq\x64\jq.exe
) ELSE (
	SET seven_zip=%parent%7za.exe
	SET jq=%parent%jq.exe
)

:: Ensure parent doesn't have a trailing slash
CALL :remove_trailing_slash parent

:: ///////////////////////////////////////////////////////////////////////

:: ----------------------------------------------------------------------
:: USER INPUT
:: ----------------------------------------------------------------------

SET user_config=%~1
SET logs=%~2
SET input=%~3
SET output=%~4
SET file_types=%~5
SET options=%~6

SET /A errno=0
SET /A ERROR_USER_CONFIG=1
SET /A ERROR_LOGS=2
SET /A ERROR_INPUT=4
SET /A ERROR_OUTPUT=8
SET /A ERROR_FILE_TYPES=16
SET /A ERROR_COMPRESS_FILES=32
SET /A ERROR_BACKUP_NAME=64

ECHO:

:: Ensure user config is non-empty
:: ----------------------------------------------------------------------
IF [%user_config%] == [] (
	SET /A "errno=!errno!|%ERROR_USER_CONFIG%"
	ECHO [ERROR]: Please add a user config path, e.g. "C:\Users\Username\Desktop\user_config.json"
	ECHO:
	GOTO skip_user_config_check
)
:: Ensure user config path exists
:: ----------------------------------------------------------------------
IF NOT EXIST "%user_config%" (
	SET /A "errno=!errno!|%ERROR_USER_CONFIG%"
	ECHO [ERROR]: User config path does not exist, "%user_config%"
	ECHO:
)
:skip_user_config_check

:: Ensure logs is non-empty
:: ----------------------------------------------------------------------
IF [%user_config%] == [] (
	SET /A "errno=!errno!|%ERROR_LOGS%"
	ECHO [ERROR]: Please add a logs path, e.g. "C:\Users\Username\Desktop\ntsg-backup-logs"
	ECHO:
	GOTO skip_logs_check
)
:: Ensure logs path exists
:: ----------------------------------------------------------------------
IF NOT EXIST "%logs%" (
	MKDIR "%logs%"
)
:skip_logs_check

:: Ensure input is non-empty
:: ----------------------------------------------------------------------
IF [%input%] == [] (
	SET /A "errno=!errno!|%ERROR_INPUT%"
	ECHO [ERROR]: Please add an input path, e.g. "C:\Users\Username"
	ECHO:
	GOTO skip_input_check
)
:: Ensure input path does not have a trailing slash
:: ----------------------------------------------------------------------
CALL :remove_trailing_slash input
:: Ensure input path exists if it's non-empty
:: ----------------------------------------------------------------------
IF NOT EXIST "%input%" (
	SET /A "errno=!errno!|%ERROR_INPUT%"
	ECHO [ERROR]: Input path does not exist, "%input%"
	ECHO:
)
:skip_input_check

:: Ensure output is non-empty
:: ----------------------------------------------------------------------
IF [%output%] == [] (
	SET /A "errno=!errno!|%ERROR_OUTPUT%"
	ECHO [ERROR]: Please add an output path, e.g. "C:\Backups"
	ECHO:
	GOTO skip_output_check
)
:: Ensure output path does not have a trailing slash
:: ----------------------------------------------------------------------
CALL :remove_trailing_slash output
:: Ensure output path exists if it's non-empty
:: ----------------------------------------------------------------------
IF NOT EXIST "%output%" (
	SET /A "errno=!errno!|%ERROR_OUTPUT%"
	ECHO [ERROR]: Output path does not exist, "%output%"
	ECHO:
)
:skip_output_check

:: Ensure file_types is non-empty (needs to be checked now since 
:: the user config checks may skip over the file types checks)
:: ----------------------------------------------------------------------
IF [%file_types%] == [] (
	SET /A "errno=!errno!|%ERROR_FILE_TYPES%"
	ECHO [ERROR]: Please add a file type section name that is from user_config.json, e.g. "documents"
	ECHO:
) 

:: Skip all jq related checks if the user_config is empty (it is skipped
:: now instead of when the user_config was checked so all parameters get
:: checked and reported to the user)
:: ----------------------------------------------------------------------
IF [%user_config%] == [] (
	GOTO skip_jq_checks
)
:: Skip all jq related checks if the user_config path does not exist
:: ----------------------------------------------------------------------
IF NOT EXIST %user_config% (
	GOTO skip_jq_checks
)

:: Skip the file check if file_types is empty
:: ----------------------------------------------------------------------
IF [%file_types%] == [] (
	GOTO skip_file_check
) 
:: Ensure that the file_types exist in the JSON file if it's non-empty
:: ----------------------------------------------------------------------
SET tmp_file="tmp_check_files"
TYPE "%user_config%" | "!jq!" ".file_types.%file_types%" > %tmp_file%
SET /P file_check= < %tmp_file%
DEL %tmp_file%
IF /I "!file_check!" EQU "null" (
	SET /A "errno=!errno!|%ERROR_FILE_TYPES%"
	ECHO [ERROR]: The given file section name value, "!file_types!", does not exist in user_config.json
	ECHO:
)
:skip_file_check

:: Ensure that the compress_files value is valid
:: ----------------------------------------------------------------------
SET tmp_file="tmp_check_compress_files"
TYPE "%user_config%" | "!jq!" ".compression.compress_after_copy" > %tmp_file%
SET /P compress_files= < %tmp_file%
DEL %tmp_file%
SET /A cf_check=0
SET /A CF_NOT_TRUE=1
SET /A CF_NOT_FALSE=2
IF /I NOT [!compress_files!] == ["true"] SET /A "cf_check=!cf_check!|%CF_NOT_TRUE%"
IF /I NOT [!compress_files!] == ["false"] SET /A "cf_check=!cf_check!|%CF_NOT_FALSE%"
IF "!cf_check!" EQU "3" (
	SET /A "errno=!errno!|%ERROR_COMPRESS_FILES%"
	ECHO [ERROR]: The given compress files after copy value, !compress_files!, in user_config.json is invalid; valid values are "true" or "false".
	ECHO:
)
:: Ensure that the compress_type value is valid if we want to compress 
:: ----------------------------------------------------------------------
IF /I [!compress_files!] == ["true"] (
	SET tmp_file="tmp_check_compress_type"
	TYPE "%user_config%" | "!jq!" ".compression.compress_type" > %tmp_file%
	SET /P compress_type= < %tmp_file%
	DEL %tmp_file%
	SET /A cf_check=0
	SET /A CF_NOT_7Z=1
	SET /A CF_NOT_ZIP=2
	SET /A CF_NOT_TAR=4
	IF NOT [!compress_type!] == ["7z"] SET /A "cf_check=!cf_check!|!CF_NOT_7Z!"
	IF NOT [!compress_type!] == ["zip"] SET /A "cf_check=!cf_check!|!CF_NOT_ZIP!"
	IF NOT [!compress_type!] == ["tar"] SET /A "cf_check=!cf_check!|!CF_NOT_TAR!"
	IF "!cf_check!" EQU "7" (
		SET /A "errno=!errno!|%ERROR_COMPRESS_FILES%"
		ECHO [ERROR]: The given compress type value, !compress_type!, in user_config.json is invalid; valid values are {"7z", "zip", "tar"}
		ECHO:
	)
	CALL :unquote compress_type !compress_type!
)

:: Ensure that, if compress_files is true, that backup_name is valid and 
:: non-empty
:: ----------------------------------------------------------------------
IF /I [!compress_files!] == ["true"] (
	SET tmp_file="tmp_check_backup_name"
	TYPE "%user_config%" | "!jq!" ".compression.backup_name" > %tmp_file%
	SET /P backup_name= < %tmp_file%
	DEL %tmp_file%
	CALL :unquote backup_name !backup_name!

	IF /I ["!backup_name!"] == ["null"] (
		GOTO invalid_backup_name
	)
	IF /I ["!backup_name!"] == [""] (
		GOTO invalid_backup_name
	)

	:: backup_name was in the config file and wasn't an empty value
	GOTO valid_backup_name

	:: backup_name was not in the config or was an empty value
	:invalid_backup_name
	SET /A "errno=!errno!|%ERROR_BACKUP_NAME%"
	ECHO [ERROR]: Please add a non-empty name for your backup in user_config.json, e.g. "home-dir"
	ECHO:
)
:valid_backup_name
:skip_jq_checks

:: Error validation
:: ----------------------------------------------------------------------
IF "!errno!" NEQ "0" (
	ECHO [Usage]: ntsg_backup.cmd ^<user config^> ^<logs^> ^<input^> ^<output^> ^<file type section name^> [robocopy options]
	GOTO :EOF
)

:: Ensure the backup_name has a default value if compress_files is false.
IF /I [!compress_files!] == ["false"] (
	SET backup_name=ntsg-robocopy
	ECHO [WARNING]: backup_name in user_config.json is ignored because compress_files is false."!backup_name!" is used as part of the log file name.
	ECHO:
)

:: Ensure options is non-empty; it's optional, so it just sets a default
:: value instead of erroring out
:: ----------------------------------------------------------------------
CALL :get_datetime curr_datetime
SET log_file="%logs%\!backup_name!__backup-!file_types!_!curr_datetime!.log"
IF [!options!] == [] (
	SET options=/S /XO /NDL
)
SET options=!options! /LOG+:!log_file! /TEE

:: ///////////////////////////////////////////////////////////////////////

:: ----------------------------------------------------------------------
:: BACKUP
:: ----------------------------------------------------------------------

:: Create a directory to copy into IF compress_after_copy is true
:: ----------------------------------------------------------------------
IF /I [!compress_files!] == ["true"] (
	SET output=!output!\!backup_name!__backup-!file_types!_!curr_datetime!
	MKDIR "!output!"
)

:: Gather the file types associated from the argument passed in for the
:: user config file  
:: ----------------------------------------------------------------------
SET tmp_file="tmp_joined_files"
TYPE "%user_config%" | "!jq!" ".file_types.%file_types% | join(\" \")" > %tmp_file%
SET /P all_file_types= < %tmp_file%
DEL %tmp_file%
CALL :unquote all_file_types !all_file_types!

:: Robocopy
:: ----------------------------------------------------------------------
CALL :get_pretty_datetime tmp_datetime
SET tmp_msg="[!tmp_datetime!]: BEGIN ROBOCOPY. Please wait..."
CALL :echo_and_append %tmp_msg% !log_file!

ROBOCOPY "!input!" "!output!" !options! !all_file_types!

CALL :get_pretty_datetime tmp_datetime
SET tmp_msg="[!tmp_datetime!]: END ROBOCOPY."
CALL :echo_and_append !tmp_msg! !log_file!

:: Compress the directory into a compressed file and remove the directory
:: ----------------------------------------------------------------------
IF /I [!compress_files!] == ["true"] (
	CALL :get_pretty_datetime tmp_datetime
	SET tmp_msg="[!tmp_datetime!]: BEGIN 7ZIP. Please wait..."
	CALL :echo_and_append !tmp_msg! !log_file!

	SET tmp_file="tmp_7zip_output_file"

	"!seven_zip!" a -t!compress_type! "!output!.!compress_type!" "!output!\*" > !tmp_file! & type !tmp_file!

	type !tmp_file! >> !log_file!
	DEL !tmp_file!

	CALL :get_pretty_datetime tmp_datetime
	SET tmp_msg="[!tmp_datetime!]: END 7ZIP."
	CALL :echo_and_append !tmp_msg! !log_file!

	CALL :get_pretty_datetime tmp_datetime
	SET tmp_msg="[!tmp_datetime!]: Removing output directory. Please wait..."
	CALL :echo_and_append !tmp_msg! !log_file!

	RMDIR /S /Q "!output!"

	CALL :get_pretty_datetime tmp_datetime
	SET tmp_msg="[!tmp_datetime!]: Done removing output directory."
	CALL :echo_and_append !tmp_msg! !log_file!
)

GOTO :EOF

:: ///////////////////////////////////////////////////////////////////////

:: ----------------------------------------------------------------------
:: FUNCTIONS
:: ----------------------------------------------------------------------

:echo_and_append
	SET tmp_var=%1
	CALL :unquote tmp_var !tmp_var!
	ECHO ===============================================================
	ECHO( !tmp_var!
	ECHO ===============================================================

	ECHO =============================================================== >> %2
	ECHO( !tmp_var! >> %2
	ECHO =============================================================== >> %2

	GOTO :EOF

:unquote
	SET %1=%~2
	GOTO :EOF

:get_datetime
	FOR /f "tokens=2-4 delims=/ " %%a in ("%DATE%") do (
	    SET YYYY=%%c
	    SET MM=%%a
	    SET DD=%%b
	)
	FOR /f "tokens=1-4 delims=/:." %%a in ("%TIME%") do (
	    SET HH24=%%a
	    SET MI=%%b
	    SET SS=%%c
	    SET FF=%%d
	)

	SET %1=%YYYY%-%MM%-%DD%_%HH24%-%MI%-%SS%

	GOTO :EOF

:get_pretty_datetime
	FOR /f "tokens=2-4 delims=/ " %%a in ("%DATE%") do (
	    SET YYYY=%%c
	    SET MM=%%a
	    SET DD=%%b
	)
	FOR /f "tokens=1-4 delims=/:." %%a in ("%TIME%") do (
	    SET HH24=%%a
	    SET MI=%%b
	    SET SS=%%c
	    SET FF=%%d
	)

	SET %1=%YYYY%/%MM%/%DD% %HH24%:%MI%:%SS%

	GOTO :EOF

:remove_trailing_slash
	IF "!%1:~-1!" == "\" SET %1=!%1:~0,-1!
	GOTO :EOF

:: ///////////////////////////////////////////////////////////////////////