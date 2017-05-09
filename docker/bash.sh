#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport


# Make sure we’re running in the same folder as this file; http://stackoverflow.com/a/246128/223225
containing_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $containing_folder


[ -f ../.env.conf ] && source ../.env.conf # Load .gitignore’d .env.conf if it exists


if [[ $# -eq 0 ]] || [ "$1" = '-h' ] || [ "$1" = '--help' ]; then
	echo 'Get a shell inside a running Docker container for this project'
	echo 'Syntax: ./bash.sh opentext-media-management-core-app'
	echo 'The argument can be one of:'
	docker-compose config --services
	exit 0
fi


container=''

while test $# -gt 0; do # Based on http://stackoverflow.com/a/7069755/223225
	case "$1" in
		postgres-for-opentext-media-management|postgres)
			container='postgres'
			shift
			;;

		solr-for-opentext-media-management|solr)
			container='solr'
			shift
			;;

		ffmpeg-for-opentext-media-management|ffmpeg)
			container='ffmpeg'
			shift
			;;

		nginx-for-repository)
			container='nginx-for-repository'
			shift
			;;

		opentext-directory-services|otds)
			container='opentext-directory-services'
			shift
			;;

		opentext-media-management-core-app|opentext-media-management|otmm)
			container='opentext-media-management-core-app'
			shift
			;;

		opentext-media-management-indexer|otmm-indexer)
			container='opentext-media-management-indexer'
			shift
			;;

		nginx-for-proxy|proxy)
			container='nginx-for-proxy'
			shift
			;;

		maildev)
			container='maildev'
			shift
			;;

		opentext-utilities)
			container='opentext-utilities'
			shift
			;;

		*)
			container=$1
			shift
			;;
	esac
done


docker exec --interactive --tty --user root "otmm_${container}_1" bash --login || docker exec --interactive --tty --user root "otmm_${container}_1" sh
