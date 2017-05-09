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


#
# Prepare the container
#

printf "${GREEN}Configuring Solr...${NC}\n"

# If the Docker volume doesn’t already have a Solr core, copy in the empty default OTMM one
if [ ! -d /opt/solr-index/otmmcore ] && [ -d /opt/default-otmmcore/solr-index/otmmcore ]; then
	printf "${GREEN}Adding default empty OpenText Media Management core...${NC}\n"
	cp --preserve=mode,ownership,timestamps --recursive /opt/default-otmmcore/solr-index/otmmcore /opt/solr-index/
fi


# If a lockfile exists (and therefore Solr did not stop gracefully) delete it so that Solr can start
if [ -f /opt/solr-index/otmmcore/data/index/write.lock ]; then
	rm /opt/solr-index/otmmcore/data/index/write.lock
fi


#
# Configure Solr after it’s started up
#

(
	printf "${GREEN}Waiting for Solr to load...${NC}\n"
	for i in {1..100}; do (curl --silent --fail --output /dev/null --head http://localhost:8983/solr/otmm/schema/managed) > /dev/null 2>&1 && break || if [ "$i" -lt 101 ]; then sleep $((i * 2)); else printf "${RED}Unable to connect to Solr, exiting${NC}\n" && exit 1; fi; done
		printf "${GREEN}Solr started!${NC}\n"
) &
