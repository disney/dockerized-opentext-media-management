#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport


# This script runs on the host OS during deployment, to archive Docker logs before the deployment restarts Docker and erases the old logs


# Some colors, per http://stackoverflow.com/a/5947802/223225
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color


printf "${GREEN}Archiving Docker logs for $LC_MACHINE_NAME...${NC}\n"
sudo su
containers=( 'ffmpeg' 'nginx-for-proxy' 'nginx-for-repository' 'opentext-directory-services' 'opentext-media-management-core-app' 'opentext-media-management-indexer' 'postgres' 'solr' 'maildev' )
for container in "${containers[@]}"; do
	if [ "$(docker ps -q -f name=otmm_${container}_1)" ]; then
		echo "Archiving Docker logs for ${container}..."
		mkdir --parents /mnt/opentext-media-management-repository/logs/$container
		docker logs otmm_${container}_1 &> /mnt/opentext-media-management-repository/logs/$container/$(date +%Y-%m-%d-%H-%M).log || true # http://stackoverflow.com/a/2292885/223225
	else
		printf "${RED}${container} container not running...${NC}\n"
	fi
done


# Always exit successfully, so that missing logs don’t fail the deployment
exit 0
