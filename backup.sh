#!/bin/bash
set -e

# Immich Backup Script
echo "Beginning Immich backup!"
USER="user"
BACKUP_DEVICE=/dev/sda1
MOUNT_PATH=/media/$USER/yummysticc
BACKUP_PATH=/media/$USER/yummysticc
IMMICH_PATH=/home/$USER/immich/immich-app
LOG_PATH=/home/$USER/immich/logs/immich_backup.log
DATE=$(date +%Y%m%d_%H%M%S)

# Start Timer
START_TIME=$(date +%s)

# Logging Function
log() {
  echo "$DATE $1" >> "$LOG_PATH"
}

# Mount Drive
log "Mounting Drive"
if [ ! -d "$MOUNT_PATH" ]; then
  mkdir "$MOUNT_PATH"
fi
if mount "$BACKUP_DEVICE" "$MOUNT_PATH"; then
  log "Drive Mounted Successfully"
else
  log "Error Mounting Drive"
  exit 1
fi

# Database Backup
log "Beginning Database Backup"
if [ ! -d "$BACKUP_PATH/database" ]; then
  mkdir "$BACKUP_PATH/database"
fi
if docker exec -t immich_postgres pg_dumpall --clean --if-exists --username=postgres | gzip > "$BACKUP_PATH/database/dump_$DATE.sql.gz"; then
    log "Database Backup Completed"
else
    log "Database Backup Failed"
    exit 1
fi

# Limit PostgreSQL Dumps to 5
log "Limiting PostgreSQL Dumps"
find "$BACKUP_PATH/database/" -name "dump_*.sql.gz" -type f | sort -r | tail -n +6 | xargs rm -f
log "PostgreSQL Dumps Limited"

# File Backup
log "Beginning File Backup"
if [ ! -d "$BACKUP_PATH/files/immich" ]; then
  mkdir -p "$BACKUP_PATH/files/immich"
fi
if rsync -av "$IMMICH_PATH/" "$BACKUP_PATH/files/immich/"; then
    log "File Backup Completed"
else
    log "File Backup Failed"
    exit 1
fi

sleep 10s

# Unmount Drive
log "Unmounting Drive"
if umount $MOUNT_PATH; then
    log "Drive Unmounted"
else
    log "Drive Unmount Failed"
    exit 1
fi

# Permissions
chown -R "$USER:$USER" "$BACKUP_PATH"
log "Permissions set"

# Stop Timer and Calculate Duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Convert Duration to Hours, Minutes, Seconds
HOURS=$((DURATION / 3600))
MINUTES=$(( (DURATION % 3600) / 60 ))
SECONDS=$((DURATION % 60))

log "Immich backup completed successfully in ${HOURS} hours, ${MINUTES} minutes, and ${SECONDS} seconds!"
