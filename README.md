try-haxe
========

[![Build Status](https://travis-ci.org/clemos/try-haxe.png)](https://travis-ci.org/clemos/try-haxe)

The try-haxe project is a browser-based IDE for testing Haxe code.  It provides a
quick and easy environment for playing with the Haxe language and compiles to
JavaScript, Eval, HashLink or Neko, instantly viewable in the browser.  It also allows saving
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

build all containers (in project root)

```bash
docker-compose -f docker-compose-all.yml up -d
```

you should get http server on `127.0.0.1:623`

Note: you might have to adjust web container's gid for docker group, to match your outside docker's gid. also make sure outside www-data user is part of docker group.


install Haxe versions (outside container - copy selected versions from your local lix installation). new versions show up after reloading your browser.

```bash
cp -a ~/haxe/neko lixSetup/haxe/neko
cp -a ~/haxe/versions/4.1.5 lixSetup/haxe/versions
```

Recompile haxe code after you change source code outside:

`haxe build.hxml`

To close container:

`docker-compose -f docker-compose-all.yml down`

Linux:

Docker group can have a different group id / number than the web container's docker group. To fix it find docker group id:

`cat /etc/group | grep docker`

then use `docker exec -it try-haxe_web_1 /bin/bash` to enter web container and edit `/etc/group` inside:

```bash
apt install vim-tiny
vi /etc/group
# find entry with docker (should be last) and change number to host group id
:wq
service apache2 restart
```

macOS:

After building containers run:

`docker exec -it try-haxe_web_1 sh -c "chgrp docker /var/run/docker.sock; chmod g+w /var/run/docker.sock"`
