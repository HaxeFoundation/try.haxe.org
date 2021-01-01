try-haxe
========

[![Build Status](https://travis-ci.org/clemos/try-haxe.png)](https://travis-ci.org/clemos/try-haxe)

The try-haxe project is a browser-based IDE for testing Haxe code.  It provides a
quick and easy environment for playing with the Haxe language and compiles to
JavaScript, Flash or Neko, instantly viewable in the browser.  It also allows saving
and sharing of programs with the auto-generated hyperlink hash-codes.

The official project is hosted at [try.haxe.org](http://try.haxe.org).

Technical notes:
----------------
The try-haxe project is written in Haxe, with part of the application compiling to
JavaScript for use on the client, and part of the application compiling to PHP as
a backend service.  The backend PHP service provides server-side compilation of
programs as well as language auto-complete results. The backend uses Docker to enable the use of multiple Haxe versions and macro support.


Run your own instance (Docker):
----------------------

Install Docker and docker-compose:

https://www.docker.com/get-started

compile application

```bash
npm i lix
lix download
haxe build.hxml
```

prepare compilation image

```bash
cd lixSetup
docker-compose -f docker-compose-compiler.yml create
docker export -o compiler.img lixsetup_try_haxe_compiler_1
```

build application container (in project root)

```bash
docker-compose -f docker-compose-dev.yml up -d
```

start inner docker and import compilation image

```bash
docker exec -it try-haxe_web_1 /bin/bash # enter running application container

dockerd &
cd lixSetup
docker import compiler.img try-haxe_compiler:latest
exit
```

You should get http server on `127.0.0.1:623`

install Haxe versions (outside container - copy selected versions from your local lix installation). new versions show up after reloading your browser.

```bash
cp -a ~/haxe/neko lixSetup/haxe/neko
cp -a ~/haxe/versions/4.1.5 lixSetup/haxe/versions
```

Recompile haxe code after you change source code outside:

`haxe build.hxml`

To close container:

`docker-compose -f docker-compose-dev.yml down`

Run your own instance (old method):
----------------------

This guide has been tested on Ubuntu 16.04 desktop and server.

Clone this git repo and initialize its submodules:

```bash
git clone --recursive https://github.com/mrcdk/try-haxe -b docker
```

Install the needed libraries and build the `try-haxe` project:

```bash
cd try-haxe
haxelib install build.hxml
haxe build.hxml
```

Install docker following [this guide](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/).


Download the docker image that will be used when the compilation is triggered. This image `thecodec/haxe-3.3.0.slim` is a stripped down image that only contains the needed functionality to run `haxe` and `neko`. The server will mount the selected haxe version and the haxelib libraries when compiling.

```bash
docker pull thecodec/haxe-3.3.0.slim
```

Setup Apache and PHP:

- Install Apache and PHP:

```bash
sudo apt-get install apache2 php libapache2-mod-php
```

- Create a symlink from the project root folder to `/var/www`

```bash
sudo ln -s `pwd` /var/www
```

- Create the `tmp` folder where the code will be saved:

```bash
mkdir tmp
chmod a+rw tmp
```

- Enable the Apache rewrite module:

```bash
sudo a2enmod rewrite
```

- Edit the Apache configuration file with:

```bash
sudo nano /etc/apache2/sites-available/000-default.conf
```

- Modify the file adding the `try-haxe` directory configuration:

```bash
<VirtualHost>

    ...

    DocumentRoot /var/www

    <Directory "/var/www/try-haxe">
        Options FollowSymLinks
        AllowOverride All
    </Directory>

    ...

</VirtualHost>
```

- Finally restart Apache:

```bash
sudo systemctl restart apache2
```

Create a group `docker`and add the users `www-data` and your current user to it:

```bash
sudo groupadd docker
sudo gpasswd -a ${USER} docker
sudo gpasswd -a www-data docker
```

Then restart the docker service:

```bash
sudo service docker restart
```

Add the Haxe libraries that will be used by the site inside `haxe/haxelib`

- Change the `haxelib` install path to `haxe/haxelib`

```bash
haxelib setup haxe/haxelib
```

- Install all the libs from the `install.hxml` inside `haxe/haxelib`

```bash
haxelib install haxe/haxelib/install.hxml
```

Add the Haxe versions that will be listed in the site inside `haxe/versions`

You can use `haxe downloader.hxml` to download the latest Haxe development version.
