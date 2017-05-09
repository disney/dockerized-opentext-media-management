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


if [ "$DOCKER_MODE" != 'install-on-start' ]; then
	# Change passwords to the values in the environment variables
	# Per the configuration in pg_hba.conf, no password is required to run queries here
	printf "${GREEN}Setting passwords...${NC}\n"

	users=( 'tsuper' 'ffmpeg' )
	for user in "${users[@]}"; do
		# Poll until user exists (if another process is currently restoring a database dump)
		for i in {1..100}; do (psql --username $POSTGRES_USER --tuples-only --command "SELECT 1 FROM pg_roles WHERE rolname = '$user'" | grep 1) > /dev/null 2>&1 && break || if [ "$i" -lt 101 ]; then sleep $((i * 2)); else printf "${RED}Unable to connect to Postgres, exiting${NC}\n" && exit 1; fi; done
		echo "Changing password for $user..."
		psql --username $POSTGRES_USER --tuples-only --command "ALTER USER $user WITH ENCRYPTED PASSWORD '$DATABASE_USER_PASSWORD'"
	done

	psql --username $POSTGRES_USER --tuples-only --command "ALTER USER $POSTGRES_USER WITH ENCRYPTED PASSWORD '$POSTGRES_PASSWORD'"
fi
