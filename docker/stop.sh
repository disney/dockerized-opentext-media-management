#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


# Make sure we’re running in the same folder as this file; http://stackoverflow.com/a/246128/223225
containing_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $containing_folder


quiet=false
quieter=false


while test $# -gt 0; do # Based on http://stackoverflow.com/a/7069755/223225
	case "$1" in
		--quiet)
			quiet=true
			shift
			;;
		--quieter)
			quiet=true
			quieter=true
			shift
			;;
		*)
			shift
			;;
	esac
done



exit_code=0
if [ "$quiet" = true ]; then
	docker_compose_down_log=$(docker-compose down 2>&1) || exit_code=$?

	if [ "$quieter" = false ] || [ $exit_code -ne 0 ]; then
		echo "$docker_compose_down_log"
	fi
else
	docker-compose down
fi

exit $exit_code
