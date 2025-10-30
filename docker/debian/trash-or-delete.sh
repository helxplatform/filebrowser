#!/bin/bash
# Trash file, or permanently delete it if already in trash

TARGET_PATH="$1"

if [[ "$TARGET_PATH" =~ .*/\.?Trash(-[0-9]*|\/[0-9]*)?/files/.* ]]; then
  # Proceed with deletion as normal if the file is in a trash can.
  exit 0
else
  # Not in a trash can, run trash-put
  trash-put -- "$TARGET_PATH"
fi