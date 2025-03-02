#!/bin/bash
set -e

# Immich Backup Script
echo "Beginning Immich backup!"
USER="user"
BACKUP_DEVICE=/dev/sda1
MOUNT_PATH=/media/$USER/yummysticc
BACKUP_PATH=/media/$USER/yummysticc
IMMICH_PATH=/home/$USER/immich/immich-app
LOG_DIR="/home/$USER/immich/logs/"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/immich_backup_$DATE.log"

# Redirect all output to the log file
exec > "$LOG_FILE" 2>&1

# Start Timer
START_TIME=$(date +%s)

# Create Logs Directory if it doesn't exist.
if [ ! -d "$LOG_DIR" ]; then
  mkdir -p "$LOG_DIR"
fi

# Mount Drive
echo "Mounting Drive"
if [ ! -d "$MOUNT_PATH" ]; then
  mkdir "$MOUNT_PATH"
fi
if mount "$BACKUP_DEVICE" "$MOUNT_PATH"; then
  echo "Drive Mounted Successfully"
else
  echo "Error Mounting Drive"
  exit 1
fi

# Database Backup
echo "Beginning Database Backup"
if [ ! -d "$BACKUP_PATH/database" ]; then
  mkdir "$BACKUP_PATH/database"
fi
if docker exec -t immich_postgres pg_dumpall --clean --if-exists --username=postgres | gzip > "$BACKUP_PATH/database/dump_$DATE.sql.gz"; then
  echo "Database Backup Completed"
else
  echo "Database Backup Failed"
  exit 1
fi

# Limit PostgreSQL Dumps to 5
echo "Limiting PostgreSQL Dumps"
find "$BACKUP_PATH/database/" -name "dump_*.sql.gz" -type f | sort -r | tail -n +6 | xargs rm -f
echo "PostgreSQL Dumps Limited"

# File Backup
echo "Beginning File Backup"
if [ ! -d "$BACKUP_PATH/files/immich" ]; then
  mkdir -p "$BACKUP_PATH/files/immich"
fi
if rsync -av "$IMMICH_PATH/" "$BACKUP_PATH/files/immich/"; then
  echo "File Backup Completed"
else
  echo "File Backup Failed"
  exit 1
fi

# Giving the Drive time to calm down
echo "Giving the Drive time to calm down"
sleep 60s

# Unmount Drive
echo "Unmounting Drive"
if umount $MOUNT_PATH; then
  echo "Drive Unmounted"
else
  echo "Drive Unmount Failed"
  exit 1
fi

# Permissions
echo "Permissions set"
chown -R "$USER:$USER" "$BACKUP_PATH"

# Stop Timer and Calculate Duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Convert Duration to Hours, Minutes, Seconds
HOURS=$((DURATION / 3600))
MINUTES=$(( (DURATION % 3600) / 60 ))
SECONDS=$((DURATION % 60))

echo "Immich backup completed successfully in ${HOURS} hours, ${MINUTES} minutes, and ${SECONDS} seconds!"

# Log Rotation (Keep 60 Files)
echo "Rotating Log Files"
find "$LOG_DIR" -name "immich_backup_*.log" -type f | sort -r | tail -n +61 | xargs rm -f
echo "Log Files Rotated"
