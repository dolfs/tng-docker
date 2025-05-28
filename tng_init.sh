#!/bin/bash
#

log_msg()
{
	echo "$*"
}

error_msg()
{
	echo "$*"
}

# Read environment that controls everything
if [ -r .env ]; then
	source .env
fi

# Determine name of TNG host from first argument
# Normally this would be the same host as where this script runs
TNG_HOST="${1:-localhost}"

# Compute absolute path of ZIP file with TNG source code
SCRIPT_DIR="$( dirname -- "$( readlink -f -- "$0" )" )"

# See if we have, or can find, a ZIP file with source code
TNG_ZIP_FILE_PATH="${SCRIPT_DIR}/${TNG_ZIP_FILE}"
if [[ ! -f "$TNG_ZIP_FILE_PATH" || ! -r "$TNG_ZIP_FILE_PATH" ]]; then
	# Not found. As an alternate try and tng*.zip file
	TNG_ZIP_FILE="$(ls tng*.zip 2>/dev/null)"
	TNG_ZIP_FILE_PATH="${SCRIPT_DIR}/${TNG_ZIP_FILE}"
fi
if [[ ! -f "$TNG_ZIP_FILE_PATH" || ! -r "$TNG_ZIP_FILE_PATH" ]]; then
	# Still not found, must already be configured.
	error_msg "0: No ZIP file (TNG already set up?)!"
	log_msg "--- TNG might already be installed and ready to use! ---"
	exit 0
fi
log_msg "0: ZIP file \"$TNG_ZIP_FILE_PATH\""

# Compute URL to Ajax API
URL="http://${TNG_HOST:-80}/ajx_tnginstall.php"

# Temp file for cookies during Ajax seteup
COOKIE_FILE=$(mktemp /tmp/tng_cookie.XXXXXX)

cleanup()
{
	log_msg "Cleaning up installation files..."
	# Remove cookie file, zip files, and .env
	rm -f -- "$TNG_ZIP_FILE_PATH" "$COOKIE_FILE" ".env"
	[ -d patches ] && rm -fr patches
	# Script remains so docker can run it again.
	# It will do nothing if no zip file exists.
}

# Force cleanup when done
trap cleanup EXIT INT ERR

# Helper function to execute a POST to the ajax configuration backend with given parameters
#
# First argument must be name of a subroutine function in ajx_tnginstall.php
# Remaining arguments are expected to be a series of key=value strings.
# The value part of each such string will be url encoded before passing it to the
# Ajax API (to allow for various characters).
#
# The Ajax API may set cookies (and expect to read them), to affect a session. This is
# fully supported.
#
ajax_subroutine()
{
	local args=("-d" "subroutine=$1"); shift
	for kv in "$@"; do
		args+=("--data-urlencode" "$kv")
	done
	args+=("-d" targetdiv=div)
	# echo "POST: ${args[@]} ${URL}"
	# Need to be read (-b) and write (-c) cookies!
	curl -s -L -c "$COOKIE_FILE" -b "$COOKIE_FILE" "${args[@]}" "${URL}" | grep messageText | sed -e 's/<[^>]*>//g'
}

# Step 3: Set permissions (make certain files writable)
doPerms()
{
	ajax_subroutine perms
}

# Step 4: Rename (two) folders
tng_folder_env_value()
{
	local envvar="$(echo "TNG_FOLDER_$1" | tr '[:lower:]' '[:upper:]')"
	echo "${!envvar}"
}

# Default folder names
folder_names_backuppath="backups"
folder_names_gedpath="gedcom"
folder_names_backuppath="backups"
folder_names_gedpath="gedcom"
folder_names_mediapath="media"
folder_names_photopath="photos"
folder_names_documentpath="documents"
folder_names_historypath="histories"
folder_names_headstonepath="headstones"
folder_names_gendexfile="gendex"
folder_names_modspath="mods"

# Step 4: Rename two folders
doFolder()
{
	# Expect one argument, which is the last part of a folder_names_ variable.
	# If the variable is not defined, no folder rename will take place
	local oldkey="folder_names_${1}"
	local oldname="${!oldkey}"
	[ -z "$oldname" ] && return
	local newname="$(tng_folder_env_value "$1")"
	[ -z "$newname" ] && return
	[ "$oldname" = "$newname" ] && return
	ajax_subroutine folder "foldertype=$1" "foldername=$newname" "oldname=$oldname"
}

# Step 5: Choose your language and character set
doSetLang()
{
	matchCharset()
	{
		if [[ "$1" == *"(UTF-8)"* ]]; then
			echo UTF-8
		elif [[ "$1" == *"(ISO-8859-1)"* ]]; then
			echo ISO-8859-1
		elif [[ "$1" == *"(ISO-8859-2)"* ]]; then
			echo ISO-8859-2
		else
			echo ""
		fi
	}

	# Expect a full language name: <Language> (charset)
	local newcharset="$(matchCharset "$1")"
	local newlanguage=$(echo "$1" | sed -e 's/ (.*)//')
	if [ "$newcharset" == "UTF-8" ]; then
		newlanguage="$newlanguage-UTF8"
	fi
	ajax_subroutine charset "newcharset=${newcharset}" "newlanguage=${newlanguage}"
}

# Step 6: Establish connection to your database
doDBParams()
{
	# Expect: host db_name db_user db_pw db_port db_socket db_new_regex
	ajax_subroutine settings "database_host=$1" "database_name=$2" \
		"database_username=$3" "database_password=$4" \
		"database_port=$5" "database_socket=$6" "database_new_regex=$7"
}

# Step 7: Create the database tables
doTables()
{
	# Expect: table_prefix collation
	ajax_subroutine tables "table_prefix=$1" "collation=$2"
}

# Step 8: Create a user for yourself
doCreateUser()
{
	# Expect: username password realname email
	ajax_subroutine user "username=$1" "password=$2" "realname=$3" "email=$4"
}

# Step 9: Create a "tree" (a container) for your genealogy
doCreateTree()
{
	# Expect: <tree_id> <tree name>
	local newtreeid="$(echo "$1" | sed -e 's/[^a-zA-Z0-9]//')"
	if [ -z "$newtreeid" ] || [ -z "$2" ]; then
		error_msg "Tree ID and tree name must both be non-empty"
		exit 1
	fi
	ajax_subroutine tree "newtreeid=${newtreeid}" "newtreename=$2"
}

# Step 10: Select a template (or theme)
doSetTemplate()
{
	getMaxTemplateNumber()
	{
		local FOLDER="${1:-templates}"
		echo "$(ls -d "$FOLDER"/template* | sed -e "s#$FOLDER/template##g" | sort -nr | head -1)"
	}
	# Expect: template number or empty for default
	local MAX_NUM=$(getMaxTemplateNumber)
	local NUM="${1:-$MAX_NUM}"
	if [ "$NUM" -gt "$MAX_NUM" ]; then
		log_msg "Template $NUM > $MAX_NUM, adjusted!"
		NUM=$MAX_NUM
	fi
	ajax_subroutine template "newtemplate=$NUM"
}

# Modify an existing value in a .ini file.
#
# Expect: varname newvalue [ini_path] (the latter defaults to -)
doModini()
{
	local varname="$1"; shift
	[ -z "$varname" ] && return
	local subvalue="$varname = $1"; shift
	log_msg "    Setting: $subvalue"
	sed -Ee "/$varname"'[[:space:]]*=/{h;s/^([[:space:]]*(;(.*[^a-zA-Z])?)?)?'"$varname"'[[:space:]]*=.*$/'"$subvalue"'/};${x;/^$/{s//'"$subvalue"'/;H};x}' -i "${1:--}"
}

# Make modifications to php.ini as per env variables set.
# Variable names must be prefixed by "XPHP_INI_" and the remainder of the
# name must be spelled and capitalized exactly as expected in the php.ini
# file. Only existing variables in php.ini will be edited. No new ones will
# be added.
#
# Expect: [path to ini file dir] (has a default)
doPHPini()
{
	local PHP_DEPLOY_INI_FILE="php.ini-${1:-${XPHP_DEPLOY_INI:-production}}"
	shift
	local INI_FILE_DIR="${1:-${PHP_INI_DIR:-/usr/local/etc/php}}"
	local PHP_INI_FILE="${INI_FILE_DIR}/php.ini"
	log_msg "0: Installing ${PHP_DEPLOY_INI_FILE} as php.ini"
	cp "${INI_FILE_DIR}/${PHP_DEPLOY_INI_FILE}" "${PHP_INI_FILE}"
	log_msg "0: Modifying $INI_FILE"
	if [ ! -w "$PHP_INI_FILE" ]; then
		error_msg "INI file \"$PHP_INI_FILE\" does not exist"
		return
	fi
	local variables=(${!XPHP_INI_*})
	for envvar in "${variables[@]}"; do
		if [ ! -z "${!envvar+x}" ]; then
			local inivar="${envvar#XPHP_INI_}"
			doModini "$inivar" "${!envvar}" "$PHP_INI_FILE"
		fi
	done
}

# Everything happens in this directory
#
cd "$SCRIPT_DIR"

# Modify php.ini
doPHPini
log_msg "0: (Re)starting Apache to effectuate changes..."
apachectl -k start

# Unzip the distribution in the right place
#
log_msg "1a: Unpacking TNG files..."
unzip "${TNG_ZIP_FILE_PATH}" >/dev/null
chown -Rv www-data: . >/dev/null
[ -d patches ] &&  if [ "$(ls -A patches)" ]; then
	log_msg "1b: Patching TNG files..."
	(cd patches; cp -r . ..)
else
	log_msg ="1b: No patches to apply..."
fi

log_msg "2: Viewing readme.html not needed. This script will do everything..."

# Change permissions
log_msg "3: Changing file permissions..."
doPerms

# True customizations
log_msg "4: Custom rename folders..."
doFolder backuppath
doFolder gedpath
doFolder nones
doFolder mediapath
doFolder photopath
doFolder documentpath
doFolder historypath
doFolder headstonepath
doFolder gendexfile
doFolder modspath


log_msg "5: Set language..."
doSetLang "${TNG_LANG:-English (UTF-8)}"

log_msg "6: Configure database connection..."
doDBParams tng_db "$MYSQL_DATABASE" "$MYSQL_USER" "$MYSQL_PASSWORD" "${TNG_DB_PORT:-}" "${TNG_DB_SOCKET:-}" "$MYSQL_NEW_REGEX"

log_msg "7: Create database tables..."
doTables "${TNG_DB_TABLE_PREFIX:-tng_}"  "${TNG_DB_COLLATION:-utf8_general_ci}"

log_msg "8: Create TNG user..."
doCreateUser "${TNG_USER:-tng}" "${TNG_PASSWORD:-secret}" "${TNG_REALNAME:-Nobody Special}" "${TNG_EXMAIL:-nobody@acme.org}"

log_msg "9: Creating initial tree..."
doCreateTree "${TNG_TREE_ID:-tree1}" "${TNG_TREE_NAME:-My Genealogy}"

log_msg "10: Set template..."
doSetTemplate "${TNG_TEMPLATE:-1}"

log_msg "--- TNG is now installed and ready to use! ---"
