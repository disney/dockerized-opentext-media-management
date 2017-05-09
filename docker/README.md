# OpenText Media Management 16.2 Docker Containers

OpenText Media Management is a suite of several apps configured to talk to each other, which the documentation encourages us to install on separate servers. We adhere to the spirit of this recommendation by installing each component in its own Docker container:

* OpenText Media Management (OTMM) core app
* OpenText Media Management Indexer service (normally runs on same server as OTMM core app)
* OpenText Directory Services (OTDS): an app for integrating with user account systems
* Postgres: database
* Solr: database index
* Ffmpeg: video transcoder
* Nginx: static asset server
* Nginx: proxy
* MailDev: proxy for outgoing email

## Install

See [the main README file](../README.md).

## Build

To build all the Docker images, run the script in this folder:

```sh
./build.sh
```

This will create Docker images in your local repository, which you can see with `docker images`.

## Run

From this folder:

```sh
./start.sh
```

This will start the network of containers and let it run in the background. To see the logs of a particular container, you could run a command like:

```sh
./tail.sh opentext-media-management-core-app
```

## Troubleshooting conflicting ports

Docker for Mac binds to `localhost`, not a separate IP address. While this simplifies things quite a bit, it also means that there might be conflicts between the external ports we specify in `docker-compose.yml` and processes on your machine that might be listening on those same ports.

The solution is simply to disable whatever service you have that’s conflicting with the port. Use the command `sudo lsof -i -P | grep -i "listen"` to get a list of services listening on various ports.

## Debug

To login to a shell in the OTMM core app container, for example, use (from the `docker` folder):

```sh
./bash.sh opentext-media-management-core-app
```

To just dump the entire log of a particular container since it started, use:

```sh
./dump-log.sh opentext-media-management-core-app
```

## Reset

`restart.sh` will restart the Docker Compose network. Run with `--help` to see all options.

The first time you run the Docker Compose network, volumes are created to store the database and media files. If you want to **delete these volumes** and restart all containers, run `docker/restart.sh --erase-volumes`. As the name implies, you will **lose all data, both files and databases.**

## About

### Modes

There are two “modes” to the Docker images: `install-on-start` and `use-installed-files`. The mode is selected via the `DOCKER_MODE` environment variable (see `docker/.env`).

* `install-on-start` expects all the volumes to be empty or nonexistent. On initialization, this mode creates the databases and tables, and runs the installer for each app, then starts each app.
* `use-installed-files` can work with preexisting volumes. This mode extracts archives of each app’s files just after installation, and if the database is blank it restores a dump of a just-after-installation database.

### Creating new `use-installed-files` snapshots

If you need to create new archives of what the apps files or database are like just after installation (for example, after an patch is released for any of the apps), follow these steps:

0. Edit `docker-compose.override.yml` and set all the `CREATE_INSTALLED_FILES_ARCHIVE` values to `true`.
0. Edit `docker/.env` (or a system-defined environment variable) so that `DOCKER_MODE` is `install-on-start`.
0. Run `restart.sh --rebuild-docker --erase-volumes --tail=opentext-media-management-core-app`. This will erase all your Media Vault volumes, then start up the Docker network and tail the log for the OTMM core app. Wait until the app has finished starting up.
0. Run the following command:

	```sh
	cmd=$(./dump-log.sh postgres | \
		awk -F'\\|' '/docker cp/ {print $2}' | sed -E "s/"$'\E'"\[([0-9]{1,2}(;[0-9]{1,2})*)?m//g" \
		&& ./dump-log.sh opentext-directory-services | \
		awk -F'\\|' '/docker cp/ {print $2}' | sed -E "s/"$'\E'"\[([0-9]{1,2}(;[0-9]{1,2})*)?m//g" \
		&& ./dump-log.sh opentext-media-management-core-app | \
		awk -F'\\|' '/docker cp/ {print $2}' | sed -E "s/"$'\E'"\[([0-9]{1,2}(;[0-9]{1,2})*)?m//g") \
		&& mkdir -p ~/Downloads/new-snapshots \
		&& eval "$cmd" \
		&& echo 'Contents of ~/Downloads/new-snapshots:' \
		&& ls -1 ~/Downloads/new-snapshots
	```

	This will copy the new archives out of the Docker containers into `~/Downloads/new-snapshots`.

0. Upload the files in `new-snapshots` to the server where you put the files in `upload-these-somewhere` (see [main readme](../README.md)) under `opentext-media-management-16-post-install`, e.g. `http://example.com/opentext-media-management-16-post-install/opentext-media-management-core-app-installed-files-2017-01-01-00-00.tar.gz`.

0. Find and replace the old timestamp to the new in the project (so the various Dockerfiles with lines like `ENV INSTALLATION_FILES_SNAPSHOT 2017-01-01-00-00` get updated).

If you need to change *what files are in* the “installed files” archive, for example after upgrading an app to a new version which might’ve changed different files on installation, you’ll need to edit the command below the `CREATE_INSTALLED_FILES_ARCHIVE` check in `entrypoint.sh`. In order to know what changes to make, you’ll need to use `docker cp` to copy folders out of the container to your local filesystem, to create a set of “pre-installation” folders and “post-installation” folders that you can diff to see what changes were made by the installer. You also need to dump the database before/after the app install, and write database update scripts to update the database if it lacks the OTMM databases and tables.
