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
TNG_HOST="${1:-tng}"

# Compute absolute path of ZIP file with TNG source code
SCRIPT_DIR="$( dirname -- "$( readlink -f -- "$0" )" )"

# See if we have, or can find, a ZIP file with source code
TNG_ZIP_FILE_PATH="${SCRIPT_DIR}/${TNG_ZIP_FILE}"
if [[ ! -f "$TNG_ZIP_FILE_PATH" || ! -r "$TNG_ZIP_FILE_PATH" ]]; then
	TNG_ZIP_FILE="$(ls tng*.zip 2>/dev/null)"
	TNG_ZIP_FILE_PATH="${SCRIPT_DIR}/${TNG_ZIP_FILE}"
fi
if [[ ! -f "$TNG_ZIP_FILE_PATH" || ! -r "$TNG_ZIP_FILE_PATH" ]]; then
	error_msg "0: No ZIP file (TNG already set up?)!"
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
	# Expect: host db_name db_user db_pw db_port db_socket
	ajax_subroutine settings "database_host=$1" "database_name=$2" \
		"database_username=$3" "database_password=$4" \
		"database_port=$5" "database_socket=$6"
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
	# Expect: template number or empty for default
	ajax_subroutine template "newtemplate=${1:-23}"
}

# Unzip the distribution in the right place
#
cd /var/www/html

# Bail if zip file is not present (prevents dual configuration)
#
if [ ! -r "${TNG_ZIP_FILE_PATH}" ]; then
	error_msg "TNG already unpacked and configured, or ZIP file missing: exit!"
	exit 0
fi

log_msg "1: Unpacking TNG files..."
unzip "${TNG_ZIP_FILE_PATH}" >/dev/null
chown -Rv www-data: . >/dev/null

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
doDBParams tng_db "$MYSQL_DATABASE" "$MYSQL_USER" "$MYSQL_PASSWORD" "${TNG_DB_PORT:-}" "${TNG_DB_SOCKET:-}"

log_msg "7: Create database tables..."
doTables "${TNG_DB_TABLE_PREFIX:-tng_}"  "${TNG_DB_COLLATION:-utf8_general_ci}"

log_msg "8: Create TNG user..."
doCreateUser "${TNG_USER:-tng}" "${TNG_PASSWORD:-secret}" "${TNG_REALNAME:-Nobody Special}" "${TNG_EXMAIL:-nobody@acme.org}"

log_msg "9: Creating initial tree..."
doCreateTree "${TNG_TREE_ID:-tree1}" "${TNG_TREE_NAME:-My Genealogy}"

log_msg "10: Set template..."
doSetTemplate "${TNG_TEMPLATE:-}"

log_msg "--- TNG is now installed and ready to use! ---"
