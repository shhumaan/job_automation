#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "📦 Job Automation Backup Script"
echo "==============================="

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR/.." || exit 1

# Load environment variables
if [ -f ".env" ]; then
  source .env
else
  echo -e "${RED}❌ .env file not found${NC}"
  exit 1
fi

# Make sure backup path exists
if [ ! -d "$BACKUP_PATH" ]; then
  echo -e "${YELLOW}Creating backup directory at $BACKUP_PATH${NC}"
  mkdir -p "$BACKUP_PATH"
fi

# Timestamp for backup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_PATH/job_automation_backup_$TIMESTAMP.tar.gz"

# Check if containers are running
if ! docker-compose ps | grep -q "Up"; then
  echo -e "${YELLOW}⚠️ Some containers are not running. Backup may be incomplete.${NC}"
  echo -e "${YELLOW}Do you want to continue? (y/n)${NC}"
  read -r continue_backup
  if [[ ! "$continue_backup" =~ ^[Yy]$ ]]; then
    echo "Backup cancelled."
    exit 1
  fi
fi

# Note about Supabase backup
echo -e "${YELLOW}Note: Supabase data is stored remotely and backed up by Supabase.${NC}"
echo -e "${YELLOW}This backup only includes local n8n workflows and configurations.${NC}"

# Create a list of directories to back up
BACKUP_DIRS=(
  "$EXTERNAL_VOLUME/data/n8n"
  "./config"
  "./.env"
)

# Create backup
echo "Creating backup archive..."
tar -czf "$BACKUP_FILE" "${BACKUP_DIRS[@]}" 2>/dev/null

# Check if backup was successful
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Backup completed successfully: $BACKUP_FILE${NC}"
  
  # Cleanup old backups
  if [ -n "$BACKUP_RETENTION_DAYS" ] && [ "$BACKUP_RETENTION_DAYS" -gt 0 ]; then
    echo "Cleaning up backups older than $BACKUP_RETENTION_DAYS days..."
    find "$BACKUP_PATH" -name "job_automation_backup_*.tar.gz" -mtime +"$BACKUP_RETENTION_DAYS" -delete
    echo -e "${GREEN}✅ Cleanup completed${NC}"
  fi
  
  # Display backup size
  BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  echo "Backup size: $BACKUP_SIZE"
  
  # Check remaining disk space
  DISK_SPACE=$(df -h "$BACKUP_PATH" | tail -n 1 | awk '{print $4 " free out of " $2}')
  echo "Remaining disk space: $DISK_SPACE"
else
  echo -e "${RED}❌ Backup failed${NC}"
  exit 1
fi

echo ""
echo "===== Backup Summary ====="
echo "Timestamp: $(date)"
echo "Backup file: $BACKUP_FILE"
echo "Size: $BACKUP_SIZE"
echo "Includes: n8n workflows, configuration files"
echo "Note: Supabase data is not included in this backup as it's maintained by Supabase."
echo ""
echo "To restore this backup:"
echo "1. Stop all containers: docker-compose down"
echo "2. Extract the backup: tar -xzf $BACKUP_FILE -C /"
echo "3. Start containers: docker-compose up -d"
echo ""
echo "For scheduled backups, add this to crontab:"
echo "0 2 * * * $SCRIPT_DIR/backup.sh > $EXTERNAL_VOLUME/logs/backup_\$(date +\%Y\%m\%d).log 2>&1"

exit 0 