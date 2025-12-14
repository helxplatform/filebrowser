#!/bin/bash

set -ex

TARGET="/var/run/helx"
LINK_NAME="$HOME/helx"

# Check if a symlink by that name already exists
if [ -L "$LINK_NAME" ]; then
    echo "Removing existing symlink: $LINK_NAME"
    rm "$LINK_NAME"
fi

# Check if a file or directory exists at that path (not a symlink)
if [ -e "$LINK_NAME" ]; then
    echo "Error: $LINK_NAME exists and is not a symlink. Aborting."
    exit 1
fi

# Create the symbolic link
ln -s "$TARGET" "$LINK_NAME"

echo "Created symlink: $LINK_NAME -> $TARGET, Return code=[$?]"
