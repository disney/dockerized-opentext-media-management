#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport


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


volumes=( 'otmm_opentext-directory-services-data' 'otmm_postgres-data' 'otmm_repository' 'otmm_solr-index' 'otmm_video-staging' )
for volume in "${volumes[@]}"; do
	# If the volume exists locally, remove it
	if docker volume ls -q | grep -q "$volume" ; then
		if [ "$quiet" = true ]; then
			exit_code=0
			docker_volume_rm=$(docker volume rm "$volume" 2>&1) || exit_code=$?

			if [ "$quieter" = false ] || [ $exit_code -ne 0 ]; then
				echo "$docker_volume_rm"
			fi
		else
			echo "Removing volume $volume..."
			docker volume rm "$volume"
		fi
	fi
done
