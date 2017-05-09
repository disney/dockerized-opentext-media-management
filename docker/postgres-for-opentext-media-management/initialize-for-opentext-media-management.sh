#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


# Move config file into place on attached volume
/bin/mv -f /var/lib/postgresql/pg_hba.conf /var/lib/postgresql/data/
/bin/mv -f /var/lib/postgresql/postgresql.conf /var/lib/postgresql/data/
chown postgres:postgres /var/lib/postgresql/data/*.conf
# Reload config settings, per http://www.heatware.net/databases/postgresql-reload-config-without-restarting/
psql --username $POSTGRES_USER --command 'SELECT pg_reload_conf();'


# Create folders to contain OpenText Media Management tablespaces
# Per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-igd/en/html/pstgrs-db-prep.htm
tablespaces=( 'catalog' 'context' 'cs' 'objstacks' 'pm' 'uois' 'ffmpeg' )
for tablespace in "${tablespaces[@]}"; do
	mkdir -p "/var/lib/postgresql/data/opentext-media-management/data/$tablespace" "/var/lib/postgresql/data/opentext-media-management/index/$tablespace" # Will do nothing if folder already exists
done
chown -R postgres:postgres /var/lib/postgresql/data/opentext-media-management/


# If we’re not installing the apps on start, and the otmm database doesn’t exist, restore the dump
if [ ! "$DOCKER_MODE" = 'install-on-start' ]; then
	if ! psql --username $POSTGRES_USER --tuples-only --command "SELECT 1 FROM pg_database WHERE datname = 'otmm'" | grep -q 1; then

		psql --username $POSTGRES_USER --file /database-post-opentext-media-management-installation.sql \
		&& rm /database-post-opentext-media-management-installation.sql
	fi
fi


# It’s on us to create the ffmpeg database, so create and configure it if it doesn’t already exist
if ! psql --username $POSTGRES_USER --tuples-only --command "SELECT 1 FROM pg_database WHERE datname = 'ffmpeg'" | grep -q 1; then
	# The - option in <<-EOSQL suppresses leading tabs but *not* spaces. :)
	# SQL command based on example in https://hub.docker.com/_/postgres/
	psql --set ON_ERROR_STOP=1 --username $POSTGRES_USER <<-EOSQL
			CREATE TABLESPACE ffmpeg_data LOCATION '/var/lib/postgresql/data/opentext-media-management/data/ffmpeg';
			CREATE TABLESPACE ffmpeg_index LOCATION '/var/lib/postgresql/data/opentext-media-management/index/ffmpeg';
			CREATE DATABASE ffmpeg ENCODING 'UTF-8' LC_COLLATE 'en_US.utf8' LC_CTYPE 'en_US.utf8';
			CREATE USER ffmpeg WITH PASSWORD '$DATABASE_USER_PASSWORD';
			GRANT ALL PRIVILEGES ON DATABASE ffmpeg TO ffmpeg;
		EOSQL
fi
