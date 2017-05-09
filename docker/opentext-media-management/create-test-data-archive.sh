#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
# set -o nounset
set -o allexport
# set -o xtrace


# This file assumes it is being sourced from entrypoint.sh, including the environment variables available from that context


printf "${GREEN}Creating an archive of assets repository...${NC}\n"
tar --gzip --create --file /repository-with-test-assets-$TIMESTAMP.tar.gz $TEAMS_REPOSITORY_HOME/data/repository
printf "${GREEN}Database dump ready! Copy it out of the repo via:${NC}\n"
printf "${YELLOW}docker cp otmm_opentext-media-management-core-app_1:/repository-with-test-assets-$TIMESTAMP.tar.gz ~/Downloads/new-snapshots${NC}\n"
