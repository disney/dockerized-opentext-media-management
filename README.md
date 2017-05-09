# OpenText Media Management 16.2 in Docker

This repository contains code to run OpenText Media Management 16.2 within a Docker environment. A version of this codebase with customizations added is called Media Vault, used by Walt Disney Imagineering.

Because this repo is open source, OpenText’s proprietary files are not included; however, I’ve written instructions for where to get all the files you need and where to put them. You’ll also need to do some additional assembly, as the installation process for OpenText Media Management generates other files that need to be copied to separate servers (such as Solr and FFMpeg). Finally, since you’ll want to have a database that persists between restarts, you’ll need to create snapshots of some of the Docker containers after all this assembly is complete. Since the original installation files, the files that need to be copied as part of installation, and the post-installation snapshots all contain OpenText proprietary code, unfortunately I can’t distribute any of those files in the repo. But fear not! Putting this all together is less work than actually installing OpenText Media Management per OpenText’s instructions.

These instructions assume you are using a Mac with at least 16 GB of RAM.

## Set up a file server

A common pattern in Docker is for the `Dockerfile` (the file with instructions on how to build a Docker image) to download a binary as part of its instructions. For example one line would say something like `curl http://example.com/install.tar.gz` and the next line would extract the archive into a folder. This repo’s `Dockerfile`s contain many such instructions, and for open source binaries like the Nginx installer you don’t need to do anything. However some `Dockerfile`s want to download the OpenText installers and other proprietary binaries mentioned above. Since I can’t post these files publicly, you’ll need to find or set up a server where these files can be hosted, so that they can be downloaded as part of the build. They can’t be served from `localhost`.

A good place to put these files is an object storage server, such as Amazon’s S3. These instructions assume you can also sort the files into subfolders. Later on you will be setting an environment variable to the "base" of the hostname and path of this server. For example if you get an object server at `example.com` and a top-level folder called `dockerized-otmm`, your base will be `http://example.com/dockerized-otmm`. Inside there we will create subfolders like `opentext-media-management-16.2`, containing files like `mediamgmt_16.2_linux.iso`; for full URLs like `http://example.com/dockerized-otmm/opentext-media-management-16/media-manager.tar.gz`.

Once you have this ready, edit the `docker/.env` file in this repo (note the leading dot) and change the last line to define your server path, like:

```bash
OBJECTS_ROOT_URL= http://example.com/dockerized-otmm
```

## Get installer binaries

Login to [OpenText Connect for Media Management](https://knowledge.opentext.com/knowledge/cs.dll/open/16517187). On the left click Software Downloads, then [Media Management 16.2](https://knowledge.opentext.com/knowledge/cs.dll?func=ll&objId=68256727&objAction=browse&sort=name). Download [Media Management 16.2 Master Suite for Linux ISO (971 MB)](https://knowledge.opentext.com/knowledge/cs.dll?func=ll&objid=68261956&objaction=location&nexturl=%2Fknowledge%2Fcs%2Edll%3Ffunc%3Dll%26objId%3D68256727%26objAction%3Dbrowse%26viewType%3D1). You should receive a file named `mediamgmt_16.2_linux.iso`, with SHA `18f6289bbe19b1c9b635b7bccae4b2610a300fe5`.

Also login to [OpenText Connect for Directory Services](https://knowledge.opentext.com/knowledge/llisapi.dll/open/18985354). On the left click Software Downloads, then [Directory Services 16.2.0](https://knowledge.opentext.com/knowledge/llisapi.dll?func=ll&objId=67810138&objAction=browse&sort=name). Click [Linux](https://knowledge.opentext.com/knowledge/llisapi.dll?func=ll&objId=67808916&objAction=browse&viewType=1), then [OTDS-1620-LNX6.tar (114 MB)](https://knowledge.opentext.com/knowledge/llisapi.dll?func=ll&objid=67816396&objaction=location&nexturl=%2Fknowledge%2Fllisapi%2Edll%3Ffunc%3Dll%26objId%3D67808916%26objAction%3Dbrowse%26viewType%3D1). You should receive a file named `OTDS-1620-LNX6.tar`, with SHA `52b2cad2bb914a3cf4d663c5812ad1518b5fe426`.

Upload both of these to your file server, so that they’re accessible via URLs like `http://example.com/dockerized-otmm/opentext-media-management-16.2/mediamgmt_16.2_linux.iso` and `http://example.com/dockerized-otmm/opentext-media-management-16.2/OTDS-1620-LNX6.tar`.

For the rest of this README I will refer to just `$OBJECTS_ROOT_URL` instead of `http://example.com/dockerized-otmm`, so you’ll see URLs like `$OBJECTS_ROOT_URL/opentext-media-management-16.2/mediamgmt_16.2_linux.iso`.

## First startup

Install [Docker for Mac](https://docs.docker.com/docker-for-mac/install/) and run it.

In the menu bar, click the Docker icon ![Whale](https://docs.docker.com/docker-for-mac/images/whale-x.png) and then `Preferences`. Set `Memory` to `8 GB` or higher.

At a terminal prompt, navigate to the root of this repo and run `start.sh`. Docker Compose should start up and build the images, then run them. Part of building the images will be downloading the files you uploaded in the last section. You can continue to the next two steps while the images build.

In Finder, navigate to the root of this repo, then `docker/nginx-for-proxy/ssl/README.md`. Follow the steps in that file to create `localhost.key`, `localhost.pem` and `dhparam.pem` and set your system to trust them.

Update `docker/docker-compose.override.yml` and `deploy/-default.yml` with the values of the just-created `localhost.key`, `localhost.pem` and `dhparam.pem` files (see the comments in the `.yml` files).

That’s it! When Docker Compose has finished building and the app has started up, go to `https://localhost` and you should see the OpenText login page. You can login as `tsuper` / `MediaVault`.

## Solr

So OpenText Media Management 16.2 is running, but search doesn’t work. There is a Docker container for Solr, but we still need to follow the steps in the OTMM installation guide that tell us to copy some files from the OTMM server to the Solr server. In our case, however, we’ll be copying those files to your file server.

We’re going to be following [OpenText’s instructions for configuring Solr as a remote server](http://webapp.opentext.com/piroot/medmgt/v160200/medmgt-igd/en/html/_manual.htm) (since that’s functionally how our separate Docker containers act). In a terminal window, navigate to this repo’s `docker` folder and run:

```bash
./bash.sh otmm
```

This gets you a command prompt _inside_ the running OTMM core app Docker container. It’s like using SSH to get a commant prompt in a remote server. Now follow OpenText’s instructions:

```bash
cd $TEAMS_HOME/install/ant
ant create-solr-index
```

This creates a folder `$TEAMS_HOME/solr5_otmm`. Let’s compress the folder into an archive so that we can upload it to our server:

```bash
tar --gzip --create --file /solr5_otmm.tar.gz $TEAMS_HOME/solr5_otmm
exit
```

Now we should be back at the command prompt of the Mac. Copy the file we just created out of the OTMM container’s filesystem into the Mac’s:

```bash
docker cp otmm_opentext-media-management-core-app_1:/solr5_otmm.tar.gz ~/Downloads
```

Upload the file from your `Downloads` folder to your file server, so that it is accessible via `$OBJECTS_ROOT_URL/opentext-media-management-16.2/solr5_otmm.tar.gz`.

Finally, we need to update the Solr Docker container to use this file you just uploaded. The code is already there, but commented out, because it can’t be built without the file you just uploaded. Open `docker/solr-for-opentext-media-management/Dockerfile` and remove the `# `s from lines 17, 18 and 19:

```bash
# RUN mkdir --parents /opt/solr-index/ /opt/default-otmmcore/solr-index/ \
# 	&& curl --retry 999 --retry-max-time 0 -C - --show-error --location $OBJECTS_ROOT_URL/opentext-media-management-16.2/solr5_otmm.tar.gz \
# 		| tar --extract --gunzip --strip-components=3 --directory /opt/default-otmmcore/solr-index
```

should become:

```bash
RUN mkdir --parents /opt/solr-index/ /opt/default-otmmcore/solr-index/ \
	&& curl --retry 999 --retry-max-time 0 -C - --show-error --location $OBJECTS_ROOT_URL/opentext-media-management-16.2/solr5_otmm.tar.gz \
		| tar --extract --gunzip --strip-components=3 --directory /opt/default-otmmcore/solr-index
```

## Make `use-installed-files` snapshots

There are two “modes” to the Docker images: `install-on-start` and `use-installed-files`. The mode is defined by the `DOCKER_MODE` environment variable in `docker/.env`.

* `install-on-start` expects all the volumes to be empty or nonexistent. On initialization, this mode creates the databases and tables, and runs the installer for each app, then starts each app.

* `use-installed-files` can work with preexisting volumes. This mode extracts archives of each app’s files just after installation, and if the database is blank it restores a dump of a just-after-installation database.

You just started up the app in `install-on-start` mode. This is fine when the database is blank, or you’re willing to erase it on every startup; but presumably at some point you’ll want a persistent database, that doesn’t get wiped on every restart. For that, we’ll need to switch to `use-installed-files` mode; and to do that, we need to create the snapshots.

Fortunately, creating the snapshots is a mostly scripted process. Open `docker/docker-compose.override.yml` and change the two `CREATE_INSTALLED_FILES_ARCHIVE: 'false'` lines to `CREATE_INSTALLED_FILES_ARCHIVE: 'true'`. Note the quotes around “true”.

The `CREATE_INSTALLED_FILES_ARCHIVE` environment variable will tell our Docker scripts to create snapshots on startup. So the next step is to restart our Docker containers, including erasing the volumes, which will wipe the database and the folders that hold the uploaded files. This is necessary, because we’re still in `install-on-start` mode, and the app can’t install itself unless the database is empty.

```bash
restart.sh --rebuild-docker --erase-volumes
```

Wait until the app fully starts up again and you can login at `https://localhost/otmm/ux-html/`. Then run this command:

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

This will copy the new archives out of the Docker containers into `~/Downloads/new-snapshots`. You’ll notice that the filenames contain timestamps; this is so that you can create new snapshots in the future, if you need to. Upload those files to your server in a new subfolder called `opentext-media-management-16.2-post-install`, so that the files are available like `$OBJECTS_ROOT_URL/opentext-media-management-16.2-post-install/database-post-opentext-media-management-installation-2017-12-31-23-59.sql.gz`.

Edit `docker/docker-compose.override.yml` and change the three `CREATE_INSTALLED_FILES_ARCHIVE ` lines back to `CREATE_INSTALLED_FILES_ARCHIVE: 'false'`. Also edit `docker/.env` and change the `DOCKER_MODE` line to `DOCKER_MODE=use-installed-files`.

Now let’s restart with `erase-volumes` one more time, to ensure that everything is working:

```bash
restart.sh --rebuild-docker --erase-volumes
```

The app should start up much faster this time. Now going forward you can run just `restart.sh` to restart the app, and it will restart without erasing any data.

## Customization

If you want the app to be able to send email, and you have an SMTP email server that will accept connections from whatever machine you’re running the app on, edit `docker/docker-compose.override.yml` and change the `EMAIL_HOST` line to point to your SMTP server’s address.

If you have customizations to deploy into the OpenText Media Management server, edit `docker/opentext-media-management/deploy.sh` as appropriate to copy your files into place on startup.

## Useful Links

Once everything is installed and the Docker container network is running, you can access the various parts of the app at the following addresses:

| What | Where | User | Default Password
| --- | --- | --- | --- |
| App Home | [https://localhost/otmm/ux-html/](https://localhost/otmm/ux-html/) | tsuper | MediaVault |
| OpenText Media Management (OTMM) Administration | [https://localhost/teams/](https://localhost/teams/) | tsuper | MediaVault |
| OpenText Directory Services (OTDS) | [https://localhost/otds-admin/](https://localhost/otds-admin/) | otadmin@otds.admin | MediaVault1!
| Solr | [https://localhost/solr/](https://solr/) | solr | MediaVault |
| MailDev | [https://localhost/maildev/](https://localhost/maildev/) | tsuper | MediaVault |

The passwords above can be overridden by editing `docker/docker-compose.override.yml`. Your new passwords will take effect after restarting Docker.

## Learn More

You can learn more about how the Docker files work by reading the [Docker readme](./docker/README.md).


## Deploy

See the [Deployment README](./deploy/README.md).
