#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


# This file assumes it is being sourced from entrypoint.sh, including the environment variables available from that context


if [ -d /opt/opentext-media-management-patch-1-installer ] && [ "$OTMM_MODE" = 'core-app' ]; then
	printf "${GREEN}Installing Patch 1...${NC}\n"
	cd /opt/opentext-media-management-patch-1-installer
	ant install-patch
	rm -rf /opt/opentext-media-management-patch-1-installer
fi


if [ -d /opt/opentext-media-management-patch-2-installer ] && [ "$OTMM_MODE" = 'core-app' ]; then
	printf "${GREEN}Installing Patch 2...${NC}\n"
	cd /opt/opentext-media-management-patch-2-installer
	ant install-patch
	rm -rf /opt/opentext-media-management-patch-2-installer
fi


if [ -d /opt/opentext-media-management-hotfix-34185-installer/ ] && [ "$OTMM_MODE" = 'core-app' ]; then
	printf "${GREEN}Installing Hotfix 34185...${NC}\n"
	cd /opt/opentext-media-management-hotfix-34185-installer/
	# From ART-34185-Error_Indexing_Assets.sh (we don’t need to create backups first)
	jar uvf $TEAMS_HOME/ear/artesia.ear/artesia-ejb.jar com/artesia/server/container/task/GetPath*.class
	rm -rf /opt/opentext-media-management-hotfix-34185-installer/
fi
