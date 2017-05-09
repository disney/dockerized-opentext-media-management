#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport


# Make sure we’re running in the same folder as this file; http://stackoverflow.com/a/246128/223225
containing_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $containing_folder


cmd='docker-compose logs --follow --tail=1000'


while test $# -gt 0; do # Based on http://stackoverflow.com/a/7069755/223225
	case "$1" in
		-h|--help)
			echo 'Tail the log of the specified container'
			echo 'syntax: ./tail.sh opentext-media-management-core-app'
			exit 0
			;;

		postgres-for-opentext-media-management|postgres)
			$cmd postgres
			exit 0
			;;

		solr-for-opentext-media-management|solr)
			$cmd solr
			exit 0
			;;

		ffmpeg-for-opentext-media-management|ffmpeg)
			$cmd ffmpeg
			exit 0
			;;

		nginx-for-repository)
			$cmd nginx-for-repository
			exit 0
			;;

		opentext-directory-services|otds)
			$cmd opentext-directory-services
			exit 0
			;;

		opentext-media-management-core-app|opentext-media-management|otmm)
			$cmd opentext-media-management-core-app
			exit 0
			;;

		opentext-media-management-indexer|otmm-indexer)
			$cmd opentext-media-management-indexer
			exit 0
			;;

		media-vault-api|api)
			$cmd api
			exit 0
			;;

		nginx-for-frontend-static-assets|frontend)
			$cmd nginx-for-frontend-static-assets
			exit 0
			;;

		nginx-for-proxy|proxy)
			$cmd nginx-for-proxy
			exit 0
			;;

		maildev)
			$cmd maildev
			exit 0
			;;

		opentext-utilities)
			$cmd opentext-utilities
			exit 0
			;;

		test-assets-loader)
			$cmd test-assets-loader
			exit 0
			;;

		*)
			shift
			;;
	esac
done
