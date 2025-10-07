#!/bin/bash
set -ex

DB_DIR_PATH="$HOME/.filebrowser"
DB_PATH="$DB_DIR_PATH/filebrowser.db"
CONFIG_PATH="/settings.json"

# Ensure trash-cli is available
if ! command -v trash-put >/dev/null 2>&1; then
  echo "[setup_trash.sh]: Error: trash-put not found in PATH"
  exit 1
fi

echo "[setup_trash.sh]: Setting up recycle bin."

# Apply trash-put override
echo "[setup_trash.sh]: Configuring Filebrowser to use trash-put for deletes..."
/filebrowser cmds add before_delete "/trash-or-delete.sh \$FILE" -d "$DB_PATH" -c "$CONFIG_PATH"
echo "[setup_trash.sh]: Registered trash-cli returned return code [$?]"

echo "[setup_trash.sh]: Exiting."
