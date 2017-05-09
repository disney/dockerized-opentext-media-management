#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


# Some colors, per http://stackoverflow.com/a/5947802/223225
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color


mkdir --parents /opt/opentext-media-management-repository/database-backups/


printf "${GREEN}Waiting for Postgres to be ready...${NC}\n" # This script will die if Postgres returns `psql: FATAL:  the database system is starting up`, which it might do if it’s currently restoring a dump
for i in {1..100}; do (PGPASSWORD=$POSTGRES_PASSWORD psql --username $POSTGRES_USER --tuples-only --command "SELECT 1 FROM pg_database WHERE datname = 'media_vault'" | grep 1) > /dev/null 2>&1 && break || if [ "$i" -lt 101 ]; then sleep $((i * 2)); else printf "${RED}Unable to connect to Postgres, exiting${NC}\n" && exit 1; fi; done


printf "${GREEN}Backing up all Postgres databases..."
pg_dumpall --username $POSTGRES_USER | gzip > /opt/opentext-media-management-repository/database-backups/media-vault-database-backup.sql.gz
printf " done.${NC}\n"


printf "${GREEN}Rotating Postgres database backups..."
logrotate --force /etc/logrotate.d/postgres-backups
printf " done.${NC}\n"
