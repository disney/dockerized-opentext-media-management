#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
# set -o errexit
set -o pipefail
set -o nounset
set -o allexport


# Make sure we’re running in the same folder as this file; http://stackoverflow.com/a/246128/223225
containing_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $containing_folder


if [ -n "${DOCKER_MACHINE_NAME+1}" ]; then
	echo 'ERROR: This script only restarts a local Docker environment'
	echo 'Open a new shell where “docker-machine active” returns “No active host found”'
	exit 1
fi

if [ $(docker info --format '{{.MemTotal}}') -lt 8000000000 ]; then
	echo 'ERROR: You need to allocate at least 8GB of memory to Docker'
	echo 'See README.md'
	exit 1
fi


rebuild_docker=false
rebuild_server=false
rebuild_client=false
no_cache_flag=''
erase_volumes=false
quiet=false
quieter=false
quiet_flag=''
quieter_flag=''
only=false
tail=false
tail_all=false


while test $# -gt 0; do # Based on http://stackoverflow.com/a/7069755/223225
	case "$1" in
		-h|--help)
			echo 'Restart Docker container network'
			echo 'syntax: ./restart.sh (options)'
			echo ' '
			echo 'options:'
			echo '--help            show brief help'
			echo '--rebuild-docker  rebuild the Docker images as part of restarting'
			echo '--rebuild-server  rebuild the server-side code as part of restarting'
			echo '--rebuild-client  rebuild the client-side code as part of restarting'
			echo '--erase-volumes   delete and recreate the Docker volumes as part of restarting'
			echo '--reset           rebuilds Docker images, server- and client-side code and erases volumes'
			echo '--no-cache        rebuild Docker images without using any cached image layers (very slow)'
			echo '--only=container  restart only the specified container'
			echo '--tail=container  after restarting, tail the logs of the specified container'
			exit 0
			;;
		--rebuild-docker)
			rebuild_docker=true
			shift
			;;
		--rebuild-server)
			rebuild_server=true
			shift
			;;
		--rebuild-client)
			rebuild_client=true
			shift
			;;
		--no-cache)
			no_cache_flag='--no-cache'
			shift
			;;
		--erase-volumes)
			erase_volumes=true
			shift
			;;
		--reset)
			rebuild_docker=true
			rebuild_server=true
			rebuild_client=true
			erase_volumes=true
			shift
			;;
		--quiet)
			quiet=true
			quiet_flag='--quiet'
			shift
			;;
		--quieter)
			quiet=true
			quieter=true
			quiet_flag='--quiet'
			quieter_flag='--quieter'
			shift
			;;
		--only*)
			only="$(echo $1 | sed -e 's/^[^=]*=//g')"
			shift
			;;
		--tail*)
			tail="$(echo $1 | sed -e 's/^[^=]*=//g')"
			shift
			;;
		*)
			shift
			;;
	esac
done


if [ "$only" != false ]; then

	docker-compose restart $only

	if [ "$rebuild_docker" = true ]; then
		docker-compose build $only
	fi

else

	./stop.sh $quiet_flag $quieter_flag

	if [ "$erase_volumes" = true ]; then
		./erase-volumes.sh $quiet_flag $quieter_flag
	fi


	if [ "$rebuild_docker" = true ]; then
		./build.sh $no_cache_flag $quiet_flag $quieter_flag
	fi

	if [ "$rebuild_server" = true ]; then
		../build.sh --only-server $quiet_flag $quieter_flag
	fi

	if [ "$rebuild_client" = true ]; then
		../build.sh --only-client $quiet_flag $quieter_flag
	fi

	cd $containing_folder


	if [ "$quiet" = true ]; then
		exit_code=0
		docker_compose_up_log=$(docker-compose up -d 2>&1) || exit_code=$?

		if [ "$quieter" = false ] || [ $exit_code -ne 0 ]; then
			echo "$docker_compose_up_log"
			if [ $exit_code -ne 0 ]; then
				exit $exit_code
			fi
		fi
	else
		docker-compose up -d
	fi


fi


if [ "$tail" != false ]; then
	docker-compose logs --follow $tail
fi
