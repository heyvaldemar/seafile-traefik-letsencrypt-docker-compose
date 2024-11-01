#!/bin/bash

# seafile-restore-all-databases.sh Description
# This script facilitates the restoration of all databases from a backup.

SEAFILE_CONTAINER=$(docker ps -aqf "name=seafile-seafile")
SEAFILE_BACKUPS_CONTAINER=$(docker ps -aqf "name=seafile-backups")
SEAFILE_DB_USER="root"
MARIADB_PASSWORD=$(docker exec $SEAFILE_BACKUPS_CONTAINER printenv MARIADB_ROOT_PASSWORD)
BACKUP_PATH="/srv/seafile-mariadb/backups/"

echo "--> All available database backups:"

# Display all backups in the backup path
for entry in $(docker container exec "$SEAFILE_BACKUPS_CONTAINER" sh -c "ls $BACKUP_PATH")
do
  echo "$entry"
done

# Prompt user to select a backup
echo "--> Copy and paste the backup name from the list above to restore all databases and press [ENTER]"
echo "--> Example: seafile-mariadb-backup-YYYY-MM-DD_hh-mm.gz"
echo -n "--> "

read SELECTED_DATABASE_BACKUP

# Remove any surrounding quotes from the selected backup name
SELECTED_DATABASE_BACKUP=$(echo "$SELECTED_DATABASE_BACKUP" | tr -d "'\"")

echo "--> $SELECTED_DATABASE_BACKUP was selected"

# Stop the service container
echo "--> Stopping service..."
docker stop "$SEAFILE_CONTAINER"

# Restore all databases
echo "--> Restoring all databases..."
docker exec "$SEAFILE_BACKUPS_CONTAINER" sh -c "mariadb -h mariadb -u $SEAFILE_DB_USER --password=$MARIADB_PASSWORD -e 'DROP DATABASE IF EXISTS seafiledb; DROP DATABASE IF EXISTS ccnet_db; DROP DATABASE IF EXISTS seahub_db;' \
&& gunzip -c ${BACKUP_PATH}${SELECTED_DATABASE_BACKUP} | mariadb -h mariadb -u $SEAFILE_DB_USER --password=$MARIADB_PASSWORD"
echo "--> All databases have been restored."

# Start the service container
echo "--> Starting service..."
docker start "$SEAFILE_CONTAINER"
