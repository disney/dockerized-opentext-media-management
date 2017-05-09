#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
# set -o errexit
set -o pipefail
set -o nounset
set -o allexport


# Clean up abandoned Docker containers and images
# From http://stackoverflow.com/a/32723127/223225
docker rm -v $(docker ps --filter status=exited -q 2>/dev/null) 2>/dev/null
docker rmi $(docker images --filter dangling=true -q 2>/dev/null) 2>/dev/null
