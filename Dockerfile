FROM ubuntu:bionic
RUN export DEBIAN_FRONTEND=noninteractive; \
    ln -fs /usr/share/zoneinfo/Europe/Kiev /etc/localtime
RUN apt-get update && apt-get install -y gnupg; \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5B4869E6A9AACE33; \
    echo 'deb http://ppa.launchpad.net/haxe/releases/ubuntu bionic main' >> /etc/apt/sources.list; \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    haxe \
    apache2 \
    php \
    libapache2-mod-php \
    php-mbstring
    # docker.io
RUN a2enmod rewrite
RUN haxe -version
ADD . /srv/try-haxe
WORKDIR /srv/try-haxe
RUN [ -d /var/www/html ] && rm -rf /var/www/html; \
    ln -s $(pwd)/www /var/www/html; \
    [ ! -d $(pwd)/www/tmp ] && mkdir $(pwd)/www/tmp && chmod 777 $(pwd)/www/tmp
ENV HAXELIB_PATH www/haxe/haxelib
RUN haxelib setup www/haxe/haxelib; \
    haxelib install www/haxe/haxelib/install.hxml --always; \
    haxelib install downloader.hxml --always; \
    haxelib install build.hxml --always
RUN haxe downloader.hxml
RUN haxe build.hxml

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
