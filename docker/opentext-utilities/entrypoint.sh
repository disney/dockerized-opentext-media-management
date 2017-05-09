#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


utilities=( 'opentext-directory-services-http-endpoints-bridge' )
for utility in "${utilities[@]}"; do
	if [ -d /opt/utilities/$utility ]; then
		rm -rf /opt/utilities/$utility/*
	else
		mkdir /opt/utilities/$utility
	fi
	cp --recursive /opt/src/$utility/target/* /opt/utilities/$utility
	echo "$utility copied into /opt/utilities"
done
