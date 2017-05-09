#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


# This file assumes it is being sourced from entrypoint.sh, including the environment variables available from that context


# Copy-into-place function
function copy {
	# $1 like './src/foo/target/foo.jar', the source file
	# $2 like '$JBOSS_HOME/server/foo', the destination folder
	mkdir --parents "$2" # Make sure the target folder exists
	cp --preserve=mode,ownership,timestamps --update --recursive "$1" "$2" # Copy the file into it, preserving properties
}


printf "${GREEN}Deploying OpenText Media Management customizations...${NC}\n"
# Your customizations go here!
