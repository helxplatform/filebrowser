#!/bin/sh

set -e

DB_DIR_PATH="${HOME}/.filebrowser"
DB_PATH="${DB_DIR_PATH}/filebrowser.db"
CONFIG_PATH="/settings.json"

SAFE_SOFTLINK_HELX="/helx-softlink.sh"
SETUP_TRASH="/setup-trash.sh"

EXPECTED_HOOK='/trash-or-delete.sh $FILE'

##############################################################
# validate_db
#
#   Validates that existing db meets the following criteria:
#      1) db is readable and responding
#      2) auth.method is noauth
#      3) Correct trash-bin before-delete hook is installed
#      4) $USER is a valid database user
#
#   Parameters:
#     - none
#
#   Returns:
#     - 0 (True) if existing db meets run criteria
#     - 1 (False) if db fails any run criterion.
##############################################################
validate_db() {

    echo "[init.sh::validate_db]: Validating existing filebrowser database."

    # Verify db is readable/responding
    if ! /filebrowser -d "$DB_PATH" -c "$CONFIG_PATH" config cat \
            > /tmp/filebrowser-config.json 2>/tmp/filebrowser-config.err; then
        echo "[init.sh::validate_db]: Failed to read filebrowser config."
        cat /tmp/filebrowser-config.err || true
        return 1
    fi

    # Verify auth.method is noauth
    if ! grep -q "Auth method:[[:space:]]*noauth" /tmp/filebrowser-config.json; then
        echo "[init.sh::validate_db]: Invalid database: auth.method not set to noauth"
        return 1
    fi

    # Verify that "before_delete hook" is set to expected value
    if ! grep -Fq "$EXPECTED_HOOK" /tmp/filebrowser-config.json; then
        echo "[init.sh::validate_db]: Invalid database: before_delete hook set to invalid value."
        return 1
    fi

    # Verify db user $USER exists
    if ! /filebrowser -d "$DB_PATH" -c "$CONFIG_PATH" users ls \
	 >/tmp/filebrowser-users.json 2>/tmp/filebrowser-users.err; then
        echo "[init.sh]: Invalid database: Failed to read database users."
        cat /tmp/filebrowser-users.err || true
        return 1
    fi

    if ! grep -q "$USER" /tmp/filebrowser-users.json; then
        echo "[init.sh]: Invalid database: Bootstrap user [$USER] is not a valid database user."
        return 1
    fi

    echo "[init.sh::validate_db]: Existing DB passed validation"

    return 0
}


##############################################################
# create_random_passsord
#
#   Creates and returns a 32 bit random password
#
#   Parameters:
#     - none
#
#   Returns:
#     - String containing a random 32 bit password.
##############################################################
create_random_password() {
    echo "$(openssl rand -base64 32)"
}



##############################################################
# rebuild_database
#
#   1) Removes existing database
#   2) Creates new database that meets the following criteria:
#      a) auth.method is noauth
#      b) Correct trash-bin before-delete hook is installed
#      c) $USER is a valid database user
#
#   Parameters:
#     - none
#
#   Returns:
#     - String containing a random 32 bit password.
##############################################################
rebuild_database() {

    # Remove old db and related files
    echo "[init.sh::rebuild_db]: Removing old database."
    rm -f "$DB_PATH" "${DB_PATH}-wal" "${DB_PATH}-shm" "${DB_PATH}-journal"

    # Initialize new filebrowser config:
    echo "[init.sh::rebuild_db]: Initializing new database."
    if ! /filebrowser -d "$DB_PATH" -c "$CONFIG_PATH" config init --auth.method noauth; then
	echo "[init.sh::rebuild_db]: Database config init failed with return code = [$?]"
        return 1
    fi

    # Set up trash bin integration:
    if [ "$TRASH_CLI_ENABLED" != true ]; then
        echo "[init.sh::rebuild_db]: No trash bins detected on mounts. Skipping setup of trash-cli."
    elif [ ! -x "$SETUP_TRASH" ]; then
        echo "[init.sh::rebuild_db]: $SETUP_TRASH either not found or not executable, skipping."
    else
        echo "[init.sh::rebuild_db]: Setting up trash-cli."
        if ! "$SETUP_TRASH"; then
            # Log, but continue so at least something comes up, just no trash-bin.
            echo "[init.sh::rebuild_db]: $SETUP_TRASH failed with return code [$?]"
        fi
    fi

    # Add $USER as bootstrap db user. Default perms used (everything except admin and password lock)
    echo "[init.sh::rebuild_db]: Adding database bootstrap user [$USER]"
    if ! /filebrowser -d "$DB_PATH" -c "$CONFIG_PATH" users add "$USER" "$(create_random_password)"; then
        echo "[init.sh::rebuild_db]: Failed to add bootstrap user."
	return 1
    fi

    echo "[init.sh::rebuild_db]: Successfully rebuilt database."
    return 0
}



##############################################################
# main
#
#   1) Set up softlink to postgresql data
#   2) Ensures a valid database and bootstrap user exist
#   3) Expands script's input arguments ($ENTRYPOINT and $CMD)
#   4) Execs filebrowser's entrypoint with it's command arguments
#
#   Parameters:
#     - $@: All input arguments to the script
#
#   Returns:
#     - 0
##############################################################
main() {

    echo "[init.sh::main] Init script starting."

    # Detect if trash-cli functionality is enabled
    TRASH_BINS=$(/detect-trash-bins.sh)
    if [ -n "$TRASH_BINS" ]; then
        TRASH_CLI_ENABLED=true
    else
        TRASH_CLI_ENABLED=false
    fi

    # Set up softlink to postgresql data
    if [ -x "$SAFE_SOFTLINK_HELX" ]; then
        echo "[init.sh::main]: Running $SAFE_SOFTLINK_HELX."
        "$SAFE_SOFTLINK_HELX"
        echo "[init.sh::main]: $SAFE_SOFTLINK_HELX return code: [$?]"
    else
        echo "[init.sh::main]: $SAFE_SOFTLINK_HELX not found or not executable, skipping."
    fi

    # Ensure database directory exists
    if [ ! -d "$DB_DIR_PATH" ]; then
        echo "[init.sh::main]: Creating Filebrowser database directory at $DB_DIR_PATH."
        mkdir -p "$DB_DIR_PATH"
    else
        echo "[init.sh::main]: $DB_DIR_PATH exists."
    fi

    # If valid database exists, reuse it, otherwise, create valid database.
    if [  -f "$DB_PATH" ] && validate_db; then
        echo "[init.sh::main]: Reusing valid filebrowser.db found at $DB_PATH."
    else
        echo "[init.sh::main]: Missing or invalid filebrowser.db at $DB_PATH. Rebuilding database."
        rebuild_database
    fi

    exec "$@"
}

main "$@"
