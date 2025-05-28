# TNG Automatic Configuration for Docker

This “utility” was created to allow a fully automated deployment of TNG into a Docker setup, without having to install, then go to the `readme.html` form, and then fill out all kinds of stuff to configure. This allows an easy and repeatable process.

Why deploy in a Docker setup? There might be several reasons, and possibly others:

* You intend to deploy to a server where Docker is installed, so you can deploy multiple applications easily. This typically occurs when you “self-deploy” within your own network.
* You want a Docker-based installation for easy development and testing, even though your main deployment is not Docker-based, typically with some provider. This is particularly beneficial when you realize that “experimenting” on a “live” server is not a good idea, and you are looking for an alternative.
* You want to test out a newer or older version to compare behaviors, or to see if you want to upgrade your main server.

## In this repository

This repository contains three critical files:

* `.env`: Contains environment variable definitions to influence installation and configuration
* `docker-compose.yml`: Configuration for Docker.
* `tng_init.sh`: A bash script that is copied into the container and run there to perform configuration according to the values in `.env`.

You can also use this without Docker to automate installation. See down below.

## Installation with Docker

Before you can install, you must download the TNG source code and place the ZIP file in this directory. The file name does not matter, as long as it ends in `.zip`.

Then, to install TNG in Docker and configure it so it is ready to go, follow these steps:

1. Edit the `.env` file as necessary (see below)
2. Run and install in Docker:
   1. If you are running Docker on a remote host, create the remote context by running docker context create remote-server-- docker "//root@containers.local` and " and then switch to using that context by running docker context use containers.
   2. Run `docker compose up`. This should build an image, deploy the necessary MySQL container, and a container running Apache to serve the TNG site. A script will be run (once) to fully configure the site, based on variables defined in the `.env` file mentioned above. This is, essentially, the equivalent of manually using the `readme.html` file. Use `docker-compose up -d` to start in detached mode; however, the above is better for testing.
3. Contact your host in a browser: `http://containers.local:8888`. You should see the home page. The hostname to use depends on where your containers were deployed. The port (8888) can be changed using the `.env` file.

That’s all there is to it.

### Starting from scratch (again)

The Docker configuration uses host-mounted volumes so that the database and TNG server files are permanently preserved, even when the containers are shut down and restarted. The initialization script, when complete, removes the ZIP file, preventing the initialization from running again. This is generally what is desired.

#### Removing the permanent volumes

If you wish to remove the permanent volumes, use:

```bash
$ docker compose down -v
```

If you then bring the containers up again later, these volumes will be recreated and will again contain the ZIP file, so that initialization will occur again. However, the same `.env`, `tng_init.sh,` and ZIP files as were used initially will be used.

#### Restarting after editing the `.env` file

If you modify any one of the three critical files, or even download, replace, or unzip the ZIP file, you must start over in a different manner. This is because Docker will maintain a copy of the original image built for the TNG server, and that image contains the old files.

To force a completely new build use:

```bash
$ docker compose build --no-cache
```

Then, proceed with bringing the containers up.

### Controlling the configuration

Editing the .env file before running Docker controls the configuration. This file defines a series of variables used by the Docker Compose command and the initialization script. Most everything has a default, but you should at least look at the variables for Step 8 (create a user) and Step 9 (create a tree).

#### TNG_HTML_DIR

This specifies the directory where the TNG source files need to be placed. The default value is virtually always what you want unless you have modified the code in `tng_init.sh`.

#### PHP_VERSION

Depending on which version of TNG you intend to use, you may need to influence the version of PHP that should be installed. This is achieved by defining a value for the PHP_VERSION variable in the `.env` file.

Generally, you can use values such as “7”, “8”, or more specific values, such as “8.2”. You can find valid values on the [official page for PHP on Docker Hub](https://hub.docker.com/_/php/tags). There, look for any tag of the form “<version>-apache” and pick one of those versions. If you search for “-apache”, you will see all of them, even ones that end in “-apache-bookworm” and such. However, this install will only use the plain “-apache” versions.

When you specify a version such as “8”, what will be installed is the latest published version of PHP 8.x. If this variable is not set, the value “8” will be used.

#### Step 0 - MySQL

Here you will define or change the name of the database used, the username, and password for MYSQL (used by TNG), as well as a root password for the database. These are the variables with their defaults:

```
MYSQL_DATABASE=tngdb
MYSQL_USER=tng
MYSQL_PASSWORD=tng_secret
MYSQL_ROOT_PASSWORD=tng_very_secret
MYSQL_NEW_REGEX=false
```

The `MYSQL_NEW_REGEX` variable should be set to `true`, or `“1”` when your database is MySQL version 8 or later.

#### Step 0 - ZIP file

You must specify a specific ZIP archive used for TNG installation. You should designate the desired one by defining:

```
TNG_ZIP_FILE=tngfiles1501.zip
```

The file must be located in the same folder as the other files in this repository.

#### Step 4 - Rename (two) folders

In this step, you can configure various folders to be renamed. The first two correspond to those in the `readme.html`. The variables shown below are with their defaults, and can be uncommented and changed as desired:

```
#TNG_FOLDER_BACKUPPATH="backups"
#TNG_FOLDER_GEDPATH="gedcom"
#TNG_FOLDER_MEDIAPATH="media"
#TNG_FOLDER_PHOTOPATH="photos"
#TNG_FOLDER_DOCUMENTPATH="documents"
#TNG_FOLDER_HISTORYPATH="histories"
#TNG_FOLDER_HEADSTONEPATH="headstones"
#TNG_FOLDER_GENDEXFILE="gendex"
#TNG_FOLDER_MODSPATH="mods"
```

#### Step 5 - Choose your language

The default will be for “English (UTF-8)”, but change the variable as desired.

```
#TNG_LANG="English (UTF-8)"
```

You must pick a value from this list:

```
English (ISO-8859-1)
Afrikaans (UTF-8)
Afrikaans (ISO-8859-1)
Arabic (UTF-8)
Chinese (UTF-8)
Brazilian Portuguese (UTF-8)
Brazilian Portuguese (ISO-8859-1)
Czech (UTF-8)
Czech (ISO-8859-2)
Croatian (UTF-8)
Croatian (ISO-8859-1)
Danish (UTF-8)
Danish (ISO-8859-1)
Dutch (UTF-8)
Dutch (ISO-8859-1)
Finnish (UTF-8)
Finnish (ISO-8859-1)
French (UTF-8)
French (ISO-8859-1)
French (Quebec) (UTF-8)
German (UTF-8)
German (ISO-8859-1)
Greek (UTF-8)
Hungarian (UTF-8)
Icelandic (UTF-8)
Icelandic (ISO-8859-1)
Italian (UTF-8)
Italian (ISO-8859-1)
Norwegian (UTF-8)
Norwegian (ISO-8859-1)
Polish (UTF-8)
Polish (ISO-8859-2)
Romanian (UTF-8)
Romanian (ISO-8859-1)
Russian (UTF-8)
Serbian (UTF-8)
Serbian (ISO-8859-1)
Serbian Cyrillic (UTF-8)
Slovak (UTF-8)
Slovak (ISO-8859-1)
Spanish (UTF-8)
Spanish (ISO-8859-1)
Swedish (UTF-8)
Swedish (ISO-8859-1)
Turkish (UTF-8)
```

#### Step 6 - Establish connection to your database

On rare occasions, you may have to override one or both of these two variables, which default to empty values:

```
#TNG_DB_PORT=
#TNG_DB_SOCKET=
```

#### Step 7 - Create database tables

Tables can have a configurable prefix in their names, and you can define/change the collation order, as desired:

```
#TNG_DB_TABLE_PREFIX=tng_
#TNG_DB_COLLATION=utf8_general_ci
```

#### Step 8 - Create a user for yourself

Change these to suit your situation:

```
TNG_USER=tng
TNG_PASSWORD=secret
TNG_REALNAME="Nobody Special"
TNG_EMAIL="nobody@acme.org"
```

#### Step 9 - Create a tree

Change these to suit your situation:

```
#TNG_TREE_ID=tree1
#TNG_TREE_NAME="My Genealogy"
```

#### Step 10 - Select a template

Change to suit your needs, or leave the default:

```
#TNG_TEMPLATE=23
```

### Customize `php.ini` settings

As installed, the `php.ini` will be a copy of the supplied production version. You may need to adjust specific settings, and a mechanism is available. This is illustrated by changing the maximum file upload size from whatever its default is to 32 megabytes.

First, you can choose whether to start with `php.ini-production` or `php.ini-development` by setting a variable `XPHP_DEPLOY_INI`. Its default is “production”, but you can set it to “development” if so desired.

Next, you introduce individual settings to override what is in the deployed `php.ini`.You do this by adding in the `.env` file a variable whose name starts with `XPHP_INI_` followed by the variable's name in the `php.ini` file you wish to change, set to the desired value. Example:

```
XPHP_INI_upload_max_filesize=32M
```

This will cause any line in the php.ini file that contains a prior setting of `upload_max_filesize`, whether commented out or not, to be replaced by a line that sets the new value, without being commented out. You can introduce as many `XPHP_INI_` variables as needed.

### Applying TNG patches

Occasionally, you may use files slightly different from those within the source code in the ZIP archive. One such case is if Darrin has supplied you with one or more altered (patched) files to try a bug fix. The following mechanism is available to prevent you from having to create a modified ZIP archive.

Alongside the ZIP archive file, you can create a directory named `patches`. This directory may contain files that will be a one-for-one replacement of source files from the ZIP archive. To replace files in sub-directories, you must mimic the necessary directory structure inside the patches directory.

For example:

```
patches
├── admin
│   └── fixme.php
└── heatmap.php
    
```

This will replace the `heat map.php` file at the top level in the source code and the `fix.php` file inside the admin folder.

Once the container is prepared, the patches directory will no longer be present.

**WARNING**: If you use this facility, remember that you may not need these patches as you switch to another ZIP archive. You should then remove them because the facility will copy them, overwriting a file you likely do not want patched.

### Activating PHPmyAdmin

PHPMyAdmin can be a valuable tool in some circumstances. If you want it installed and configured as part of your deployment:

* Uncomment the lines for that configuration in the file `docker-compose.yml`
* Configure the web port to be used by editing the value of `PMA_WEB_PORT` in the `.env` file (default is 8080).

Once deployed, you will be able to access PHPMyAdmin on the configured port. The username and password to be used are those configured for MySQL.

## Use without Docker

If you perform a more traditional installation on a hosted server, you can also use this approach (although I have not exhaustively tested it). The script will still work, but the MySQL configuration is expected to correspond to an already available database (that you are responsible for creating and configuring).

1. Copy the ZIP archive into this directory.
2. Edit the `.env` file as described above.
3. Upload all files (`.env`, `tng_init.sh`, and `tngfiles.zip`) to the server’s HTML directory (typically `/var/www/html`). Leave out the `docker-compose.yml` file!
4. Log in to the server, go to the HTML directory, and execute the script `tng_init.sh`:
   1. Give it one argument, which represents the name of the server. The script assumes it can reach `http://<server>:80`.
   2. You may see an error message about failing to modify the `php.ini` file. If you still wish to make those changes, consult the instructions provided by your service provider.