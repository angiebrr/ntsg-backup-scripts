#!/bin/bash

# =======================================================================
# backup.sh
# -----------------------------------------------------------------------
# NTSG Backup Solution
# Angela Gross
# 09/2016
# -----------------------------------------------------------------------
# Uses rsync and jq to backup categories of files
# =======================================================================

# ///////////////////////////////////////////////////////////////////////

# -----------------------------------------------------------------------
# IMPORTANT VARIABLES
# -----------------------------------------------------------------------

parent_path=$( cd "$(dirname "${BASH_SOURCE}")" ; pwd -P )
jq="${parent_path}/lib/jq/jq-linux64"

# ///////////////////////////////////////////////////////////////////////

# -----------------------------------------------------------------------
# USER INPUT
# -----------------------------------------------------------------------

user_config=${1%/} # remove trailing slash
logs=${2%/} # remove trailing slash
input=${3%/} # remove trailing slash
output=${4%/} # remove trailing slash
file_types=$5
options=$6

errno=0
error_user_config=1
error_logs=2
error_input=4
error_output=8
error_file_types=16
error_compress_files=32
error_backup_name=64

cd "${parent_path}"
echo ""

# Remove quotes from beginning and ending of user_config
user_config=${user_config%\"}
user_config=${user_config#\"}
# Remove quotes from beginning and ending of logs
logs=${logs%\"}
logs=${logs#\"}
# Remove quotes from beginning and ending of input
input=${input%\"}
input=${input#\"}
# Remove quotes from beginning and ending of output 
output=${output%\"}
output=${output#\"}

# Ensure user_config is non-empty and the given file exists
# -----------------------------------------------------------------------
if [[ -z "${user_config}" ]]; then
	let "errno = errno | error_user_config"
	echo "[ERROR]: Please add an user config path, e.g. \"/home/username/user_config.json\""
	echo ""
else
	if [[ ! -f "${user_config}" ]]; then
		let "errno = errno | error_user_config"
		echo "[ERROR]: User config file does not exist, \"${user_config}\""
		echo ""
	fi
fi

# Ensure logs is non-empty and the given path exists
# -----------------------------------------------------------------------
if [[ -z "${logs}" ]]; then
	let "errno = errno | error_logs"
	echo "[ERROR]: Please add a path for logs, e.g. \"/home/username/ntsg-backup-logs\""
	echo ""
else
	if [[ ! -d "${logs}" ]]; then
		mkdir "${logs}"
	fi
fi

# Ensure input is non-empty and the given path exists
# -----------------------------------------------------------------------
if [[ -z "${input}" ]]; then
	let "errno = errno | error_input"
	echo "[ERROR]: Please add an input path, e.g. \"/home/username\""
	echo ""
else
	if [[ ! -d "${input}" ]]; then
		let "errno = errno | error_input"
		echo "[ERROR]: Input path does not exist, \"${input}\""
		echo ""
	fi
fi

# Ensure output is non-empty and the given path exists
# -----------------------------------------------------------------------
if [[ -z "${output}" ]]; then
	let "errno = errno | error_output"
	echo "[ERROR]: Please add an output path, e.g. \"/backups\""
	echo ""
else
	if [[ ! -d "${output}" ]]; then
		let "errno = errno | error_output"
		echo "[ERROR]: Output path does not exist, \"${output}\""
		echo ""
	fi
fi

# Ensure that the file_types is non-empty and exists in the JSON file
# -----------------------------------------------------------------------
if [[ -z "${file_types}" ]]; then
	let "errno = errno | error_file_types"
	echo "[ERROR]: Please add a file type section name that is from your user_config.json file, e.g. \"documents\""
	echo ""
fi

# Only process user_config variables if the user_config is non-empty and exists
if [[ ! -z "${user_config}" ]] && [[ -f "${user_config}" ]]; then

	# If file_types is non-empty, check if exists in the JSON file
	# -----------------------------------------------------------------------
	if [[ ! -z "${file_types}" ]]; then
		file_check=$(cat ${user_config} | ${jq} ."file_types"."${file_types}")
		if [[ "$file_check" == "null" ]]; then
			let "errno = errno | error_file_types"
			echo "[ERROR]: The file section name value, \"${file_types}\", does not exist in your user_config.json file"
			echo ""
		fi
	fi

	# Ensure that the compress_files value is valid
	# ----------------------------------------------------------------------
	compress_files=$(cat ${user_config} | ${jq} ."compression"."compress_after_copy")
	# Remove quotes from beginning and end
	compress_files=${compress_files%\"}
	compress_files=${compress_files#\"}
	if [[ "${compress_files,,}" != "true" ]] && [[ "${compress_files,,}" != "false" ]]; then
		let "errno = errno | error_compress_files"
		echo "[ERROR]: The given compress files after copy value, ${compress_files}, in user_config.json is invalid; valid values are \"true\" or \"false\"."
		echo ""
	fi
	# Ensure that the compress_type value is valid if we want to compress
	# ----------------------------------------------------------------------
	if [[ "${compress_files,,}" = "true" ]]; then
		# Ensure compress_type is a valid value
		compress_type=$(cat ${user_config} | ${jq} ."compression"."compress_type")
		# Remove quotes from beginning and end
		compress_type=${compress_type%\"}
		compress_type=${compress_type#\"}
		if [[ "${compress_type,,}" = "gzip" ]]; then
			compress_flag="z"
			compress_ext="tgz"
		fi
		if [[ "${compress_type,,}" = "bzip" ]]; then
			compress_flag="j"
			compress_ext="tbz"
		fi
		# Check if compress_flag variable is set
		if [[ -z ${compress_flag+x} ]]; then
			let "errno = errno | error_compress_files"
			echo "[ERROR]: The given compress type value, \"${compress_type}\", in user_config.json is invalid; valid values are {\"gzip\", \"bzip\"}"
			echo ""
		fi
		# Ensure that backup_name is non-empty
		backup_name=$(cat ${user_config} | ${jq} ."compression"."backup_name")
		# Remove quotes from backup_name
		backup_name=${backup_name%\"}
		backup_name=${backup_name#\"}
		if [[ "${backup_name,,}" == "" ]] || [[ "${backup_name,,}" == "null" ]]; then
			let "errno = errno | error_backup_name"
			echo "[ERROR]: Please add a non-empty name for your backup in user_config.json, e.g. \"home-dir\""
			echo ""
		fi
	fi
fi

# Error validation
# -----------------------------------------------------------------------
if [[ "${errno}" != 0 ]]; then
	echo "[Usage]: ntsg_backup.sh <user config> <logs> <input> <output> <file type section name> [rsync options]"
	echo ""
	exit 1
fi

# Ensure options is non-empty; it's optional, so it just sets a default
# value instead of erroring out
# -----------------------------------------------------------------------
if [[ -z "${options}" ]]; then
	options="-auv --prune-empty-dirs"
fi

# Ensure the backup_name has a default value if compress_files is false.
if [[ "${compress_files,,}" = "false" ]]; then
	backup_name="ntsg-rsync"
	echo "[WARNING]: backup_name in user_config.json is ignored because compress_files is false. \"${backup_name}\" will be used as part of the log file name."
	echo ""
fi

# Gather log information
curr_datetime=$(date '+%Y-%m-%d_%H-%M-%S')
log_path="${logs}/${backup_name}__backup-${file_types}_${curr_datetime}.log"

# ///////////////////////////////////////////////////////////////////////

# -----------------------------------------------------------------------
# BACKUP
# -----------------------------------------------------------------------

# Create a directory to copy into IF compress_after_copy is true
# -----------------------------------------------------------------------
if [[ "${compress_files,,}" = "true" ]]; then
	output="${output}/${backup_name}__backup-${file_types}_${curr_datetime}"
	options="${options} --relative "
fi

# Gather all of the file types
# -----------------------------------------------------------------------
all_file_types="$(cat ${user_config} | ${jq} "."file_types"."${file_types}" | join(\",\")")"
# Remove quotes from beginning and end
all_file_types=${all_file_types%\"}
all_file_types=${all_file_types#\"}
# Put all file types into a filter option variable that will be used in the rsync call
filter_option=""
IFS="," read -ra ADDR <<< "$all_file_types"
for file_type in "${ADDR[@]}"; do
	filter_option="${filter_option} --include=${file_type}"
done

# Perform the rsync command
# -----------------------------------------------------------------------
echo "===============================================================" 2>&1 | tee -a "${log_path}"
curr_datetime=$(date '+%Y/%m/%d %H:%M:%S')
echo "[${curr_datetime}] RSYNC BEGIN. Please wait...." 2>&1 | tee -a "${log_path}"
echo "===============================================================" 2>&1 | tee -a "${log_path}"

rsync ${options} --log-file="${log_path}" --include="*/" ${filter_option} --exclude="*" "${input}" "${output}"

echo "===============================================================" 2>&1 | tee -a "${log_path}"
curr_datetime=$(date '+%Y/%m/%d %H:%M:%S')
echo "[${curr_datetime}] RSYNC END." 2>&1 | tee -a "${log_path}"
echo "===============================================================" 2>&1 | tee -a "${log_path}"


# Compress the directory IF compress_after_copy is true
# -----------------------------------------------------------------------
if [[ "${compress_files,,}" = "true" ]]; then
	echo "===============================================================" 2>&1 | tee -a "${log_path}"
	curr_datetime=$(date '+%Y/%m/%d %H:%M:%S')
	echo "[${curr_datetime}] TAR BEGIN. Please wait..." 2>&1 | tee -a "${log_path}"
	echo "===============================================================" 2>&1 | tee -a "${log_path}"

	tar -cv${compress_flag}f "${output}"."${compress_ext}" "${output}" 2>&1 | tee -a "${log_path}"

	echo "===============================================================" 2>&1 | tee -a "${log_path}"
	curr_datetime=$(date '+%Y/%m/%d %H:%M:%S')
	echo "[${curr_datetime}] TAR END." 2>&1 | tee -a "${log_path}"
	echo "===============================================================" 2>&1 | tee -a "${log_path}"

	echo "===============================================================" 2>&1 | tee -a "${log_path}"
	curr_datetime=$(date '+%Y/%m/%d %H:%M:%S')
	echo "[${curr_datetime}] Removing output directory. Please wait..." 2>&1 | tee -a "${log_path}"
	echo "===============================================================" 2>&1 | tee -a "${log_path}"

	rm -rf "${output}"

	echo "===============================================================" 2>&1 | tee -a "${log_path}"
	curr_datetime=$(date '+%Y/%m/%d %H:%M:%S')
	echo "[${curr_datetime}] Done removing output directory." 2>&1 | tee -a "${log_path}"
	echo "===============================================================" 2>&1 | tee -a "${log_path}"
fi