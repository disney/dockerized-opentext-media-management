#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
# set -o errexit
set -o pipefail
set -o nounset
set -o allexport


# Make sure we’re running in the same folder as this file; http://stackoverflow.com/a/246128/223225
containing_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $containing_folder


# Docker is required; per http://stackoverflow.com/a/677212/223225
if ! hash docker-compose 2>/dev/null; then
	echo >&2 'Please install Docker Compose and try again.'
	exit 1
fi



no_cache=''
quiet=false
quieter=false
exit_code=0


while test $# -gt 0; do
	case "$1" in
		--no-cache)
			no_cache='--no-cache';
			shift
			;;
		--quiet)
			quiet=true;
			shift
			;;
		--quieter)
			quiet=true;
			quieter=true;
			shift
			;;
		*)
			shift
			;;
	esac
done


./cleanup.sh

if [ "$quiet" = true ]; then
	build_docker_logs=$(docker-compose build $no_cache 2>&1) || exit_code=$?

	if [ "$quieter" = false ] || [ $exit_code -ne 0 ]; then
		echo "$build_docker_logs"
	fi
else
	docker-compose build $no_cache
fi

exit $exit_code
