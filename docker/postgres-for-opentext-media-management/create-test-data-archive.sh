#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
# set -o nounset
set -o allexport
# set -o xtrace


# This file assumes it is being sourced from entrypoint.sh, including the environment variables available from that context


printf "${GREEN}Creating an backup of Postgres databases...${NC}\n"
tar --gzip --create --file /database-post-opentext-media-management-installation-with-test-data-$TIMESTAMP.tar.gz /var/lib/postgresql/data
printf "${GREEN}Database dump ready! Copy it out of the repo via:${NC}\n"
printf "${YELLOW}docker cp otmm_postgres_1:/database-post-opentext-media-management-installation-with-test-data-$TIMESTAMP.tar.gz ~/Downloads/new-snapshots${NC}\n"
