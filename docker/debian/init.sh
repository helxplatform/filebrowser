#!/bin/sh

set -e

# Backwards compatibility for old Docker image
if [ -f "/.filebrowser.json" ]; then
  ln -s /.filebrowser.json /config/settings.json

  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!! IMPORTANT INFORMATION !!!!!!!!!!!!!!!!!!!!!"
  echo "Symlinking /.filebrowser.json to /config/settings.json for backwards compatibility."
  echo ""
  echo "The volume mount configuration has changed in the latest release."
  echo "Please rename .filebrowser.json to settings.json and mount the parent directory to /config".
  echo "Read more on https://github.com/filebrowser/filebrowser/blob/master/docs/installation.md#docker"
  echo ""
  echo "This workaround will be removed in a future release."
  echo ""
fi

# Backwards compatibility for old Docker image
if [ -f "/database.db" ]; then
  ln -s /database.db /database/filebrowser.db
  
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!! IMPORTANT INFORMATION !!!!!!!!!!!!!!!!!!!!!"
  echo ""
  echo "The volume mount configuration has changed in the latest release."
  echo "Please rename database.db to filebrowser.db and mount the parent directory to /database".
  echo "Read more on https://github.com/filebrowser/filebrowser/blob/master/docs/installation.md#docker"
  echo ""
  echo "This workaround will be removed in a future release."
  echo ""
fi

if [ ! -f "/database/filebrowser.db" ]; then
  filebrowser config -d /database/filebrowser.db init
  ln -s /database/filebrowser.db /filebrowser.db
  filebrowser users add admin admin --perm.admin
fi

# Ensure configuration exists
if [ ! -f "/config/settings.json" ]; then
  cp -a /defaults/settings.json /config/settings.json
fi

SETUP_TRASH="/setup-trash.sh"
if [ -x $SETUP_TRASH ]; then
  echo "Running $SETUP_TRASH..."
  "$SETUP_TRASH"
else
  echo "$SETUP_TRASH not found or not executable, skipping..."
fi

exec "$@"
