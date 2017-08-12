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


Run your own instance:
----------------------

This guide has been tested on Ubuntu 16.04 desktop and server.

Clone this git repo and initialize its submodules:

```
git clone --recursive https://github.com/mrcdk/try-haxe -b docker
```

Install the needed libraries and build the `try-haxe` project:

```
cd try-haxe
haxelib install build.hxml
haxe build.hxml
```

Install docker following [this guide](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/).


Download the docker image that will be used when the compilation is triggered. This image `thecodec/haxe-3.3.0.slim` is a stripped down image that only contains the needed functionality to run `haxe` and `neko`. The server will mount the selected haxe version and the haxelib libraries when compiling.

```
docker pull thecodec/haxe-3.3.0.slim
```

Setup Apache and PHP:

- Install Apache and PHP:

```
sudo apt-get install apache2 php libapache2-mod-php
```

- Create a symlink from the project root folder to `/var/www`

``` 
sudo ln -s `pwd` /var/www
``` 

- Create the `tmp` folder where the code will be saved:

```
mkdir tmp
chmod a+rw tmp
```

- Enable the Apache rewrite module:

```
sudo a2enmod rewrite
```

- Edit the Apache configuration file with:

```
sudo nano /etc/apache2/sites-available/000-default.conf
```

- Modify the file adding the `try-haxe` directory configuration:

```
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

```
sudo systemctl restart apache2
```

Create a group `docker`and add the users `www-data` and your current user to it:

```
sudo groupadd docker
sudo gpasswd -a ${USER} docker
sudo gpasswd -a www-data docker
```

Then restart the docker service:

```
sudo service docker restart
```

Add the Haxe libraries that will be used by the site inside `haxe/haxelib`

- Change the `haxelib` install path to `haxe/haxelib`

```
haxelib setup haxe/haxelib
```

- Install all the libs from the `install.hxml` inside `haxe/haxelib`

```
haxelib install haxe/haxelib/install.hxml 
```

Add the Haxe versions that will be listed in the site inside `haxe/versions` 

You can use `haxe downloader.hxml` to download the latest Haxe development version.
