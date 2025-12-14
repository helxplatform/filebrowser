#!/bin/sh

set -e

DB_DIR_PATH="${HOME}/.filebrowser"
DB_PATH="${DB_DIR_PATH}/filebrowser.db"
CONFIG_PATH="/settings.json"

SAFE_SOFTLINK_HELX="/helx-softlink.sh"
SETUP_TRASH="/setup-trash.sh"


echo "init.sh script starting . . ."

# Detect if trash-cli functionality is enabled
TRASH_BINS=$(/detect-trash-bins.sh)
if [ -n "$TRASH_BINS" ]; then
    TRASH_CLI_ENABLED=true
else
    TRASH_CLI_ENABLED=false
fi

# Set ROOT_DIR
if [ -d /shared ]; then
  export ROOT_DIR="/home/$USER"
else
  export ROOT_DIR="/home"
fi

# Set up softlink to postgresql data
if [ -x "$SAFE_SOFTLINK_HELX" ]; then
    echo "[init.sh]: Running $SAFE_SOFTLINK_HELX..."
    "$SAFE_SOFTLINK_HELX"
    echo "[init.sh]: $SAFE_SOFTLINK_HELX return code: [$?]"
else
    echo "[init.sh]: $SAFE_SOFTLINK_HELX not found or not executable, skipping..."
fi

# Ensure database directory exists
if [ ! -d "$DB_DIR_PATH" ]; then
    echo "[init.sh]: Creating Filebrowser database directory at $DB_DIR_PATH..."
    mkdir -p "$DB_DIR_PATH"
else
    echo "[init.sh]: $DB_DIR_PATH exists."
fi

# If there's an existing filebrowser.db at $DB_PATH, delete it.
#
# This has to be done for new users; if a user already exists in the db,
# you can't init the db with auth.method noauth. There's also a --noauth parm that
# can be used when starting filebrowser, and a setting for the same thing, but
# they have the same problem.
#
# Ideally, we should test for an existing db at $DB_PATH, and if it exists use
# a filebrowser commands to check: 1) if noauth is set, 2) if there's a default
# user called admin, and 3) if the before_delete command hook is set to
# "/trash-or-delete.sh \$FILE". If so, we could leave the database intact and reuse it.
# This would preserve any user filebrowser changes that are saved in the existing db.
#
# All three of theses things can be checked using filebrowser commands.
echo "[init.sh]: Deleting filebrowser db . . ."
rm -f "$DB_PATH"
echo "[init.sh]: Filebrowser db  delete result = [$?]"

# Initialize the db with noauth, create a default admin user, and set before_delete command hook.
if [ ! -f "$DB_PATH" ]; then
    echo "[init.sh]: Filebrowser.db not found. Initializing Filebrowser database in $DB_DIR_PATH"
    /filebrowser -d "$DB_PATH" -c "$CONFIG_PATH" config init --auth.method noauth
    echo "[init.sh]: RC from config init --noauth = [$?]"

    if [ "$TRASH_CLI_ENABLED" = true ]; then
        if [ -x $SETUP_TRASH ]; then
            echo "[init.sh]: Running $SETUP_TRASH..."
            "$SETUP_TRASH"
            echo "[init.sh]: RC from $SETUP_TRASH = [$?]"
        else
            echo "[init.sh]: $SETUP_TRASH not found or not executable, skipping..."
        fi
    else
        echo "[init.sh]: No trash bins detected on mounts. Skipping setup for trash-cli functionality..."
    fi

    /filebrowser -d "$DB_PATH" -c "$CONFIG_PATH" users add admin admin --perm.admin
    echo "[init.sh]: RC from users add admin admin = [$?]"
else
    echo "[init.sh]: Using existing filebrowser.db located at $DB_PATH..."
fi

# Expand arguments so $HOME and $USER are forced to resolve
EXPANDED_ARGS=""
for arg in "$@"; do
  EXPANDED_ARGS="$EXPANDED_ARGS $(eval echo "$arg")"
done

echo "[init.sh]: Running [${EXPANDED_ARGS}]"
exec sh -c "$EXPANDED_ARGS"
