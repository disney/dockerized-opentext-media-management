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

TIMESTAMP="$(date +%Y-%m-%d-%H-%M)"


# We use this custom entrypoint script, rather than just the scripts copied into /docker-entrypoint-initdb.d/, because there are a few things we want to do *before* Postgres starts


# Cron has no access to our environment variables
sed --in-place "s|\$POSTGRES_PASSWORD|$POSTGRES_PASSWORD|g" /etc/cron.daily/backup-postgres
sed --in-place "s|\$POSTGRES_USER|$POSTGRES_USER|g" /etc/cron.daily/backup-postgres


if [ "${CREATE_TEST_DATA_ARCHIVE:-}" = true ]; then
	source /docker/create-test-data-archive.sh
fi


# Run cron in the background to take daily backups
cron &


# Let default entrypoint script take it from here
# This will run the initialize* scripts that were copied into /docker-entrypoint-initdb.d/
exec /docker-entrypoint.sh postgres
