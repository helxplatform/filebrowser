#!/bin/bash
# Trash file, or permanently delete it if already in trash

TARGET_PATH="$1"

if [[ "$TARGET_PATH" =~ .*/\.?Trash(-[0-9]*|\/[0-9]*)?/.* ]]; then
  # Proceed with deletion as normal if the file is in a trash can.
  exit 0
else
  # Not in a trash can, run trash-put if trash can exists, else delete it.
  mp=$(df --output=target "$TARGET_PATH" | tail -1)
  if [ "$mp" = "$HOME" ]; then
    trash_dir="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"
  else
    trash_dir="$mp/.Trash"
  fi

  if [ -d "$trash_dir" ]; then
    # Specifying trash-dir will disable uid-subdirectory behavior on shared mounts.
    trash-put --trash-dir="$trash_dir" -- "$TARGET_PATH"
    # Ensure the created trashinfo file is 666. 
    find "$trash_dir/info" -type f -user "$(whoami)" -exec chmod 666 {} \;
  else
    # Trash dir isn't configured for the mount. Proceed with normal deletion.
    exit 0
  fi
fi