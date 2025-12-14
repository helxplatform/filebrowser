#!/bin/bash
# Detect if trash-cli functionality has been enabled based on
# if there are trash directories existing on mount points.

while read -r line; do
  # extract filesystem type and mount point
  fs=$(echo "$line" | awk '{print $5}')
  mp=$(echo "$line" | awk '{print $3}')

  # Skip pseudo-filesystems
  case "$fs" in
  proc|sysfs|devtmpfs|tmpfs|cgroup|overlay|aufs)
      continue
      ;;
  esac
  # Skip well-known system paths
  case "$mp" in
  /proc*|/sys*|/dev*|/run*|/etc*)
      continue
      ;;
  esac
  # Skip non-directory mounts
  if [ ! -d "$mp" ]; then
  continue
  fi
  # Skip non-readable mounts
  if [ ! -r "$mp" ]; then
  continue
  fi
  
  # This mount is a special case that is stored under XDG_DATA_HOME.
  if [ "$mp" = "$HOME" ]; then
    TRASH_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"
  else
    TRASH_DIR="$mp/.Trash"
  fi

  if [ -d "$TRASH_DIR" ]; then
  TRASH_DIRS="$TRASH_DIRS $TRASH_DIR"
  fi
done <<EOF
$(mount)
EOF

echo "$TRASH_DIRS"