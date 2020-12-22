FROM ubuntu:bionic
RUN export DEBIAN_FRONTEND=noninteractive
RUN ln -fs /usr/share/zoneinfo/Europe/Kiev /etc/localtime
# RUN echo 'deb http://ppa.launchpad.net/haxe/releases/ubuntu bionic main' >> /etc/apt/sources.list
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    haxe \
    apache2 \
    php \
    libapache2-mod-php
    # docker.io
RUN a2enmod rewrite
RUN haxe -version
RUN [ -d /var/www/html ] && rm -rf /var/www/html
ADD . /srv/try-haxe
WORKDIR /srv/try-haxe
ENV HAXELIB_PATH haxe/haxelib
RUN haxelib setup haxe/haxelib; \
    haxelib install haxe/haxelib/install.hxml --always; \
    haxelib git thx.semver https://github.com/fponticelli/thx.semver.git
RUN ln -s $(pwd) /var/www/html
RUN haxe build.hxml
RUN haxe downloader.hxml
# RUN chmod -R 755 $(pwd)
RUN chmod -R 755 app
RUN chmod -R 777 haxe
RUN mkdir tmp && chmod 777 tmp

RUN cd /etc/apache2/sites-available; \
    sed -i '\:DocumentRoot:a\
    <Directory "/var/www/html">\n \
        Options FollowSymLinks\n \
        AllowOverride All\n \
    </Directory>\n' 000-default.conf;

RUN service apache2 start
RUN groupadd docker; \
    gpasswd -a $(whoami) docker; \
    gpasswd -a www-data docker
# RUN service docker restart
