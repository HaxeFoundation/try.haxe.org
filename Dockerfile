FROM ubuntu:focal
RUN export DEBIAN_FRONTEND=noninteractive
RUN ln -fs /usr/share/zoneinfo/Europe/Kiev /etc/localtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    apache2 \
    php \
    libapache2-mod-php \
    php-mbstring \
    docker.io 
RUN a2enmod rewrite
RUN mkdir -p /srv/try-haxe
WORKDIR /srv/try-haxe
RUN chmod -R 750 /var/www/html && chown -R www-data:www-data /var/www/html

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
RUN echo "{\n\"storage-driver\": \"vfs\"\n}\n" > /etc/docker/daemon.json
RUN echo "92.243.7.117	try.haxe.org" >> /etc/hosts
# RUN nohup dockerd &
# RUN dockerd & sleep 5; cd dind; \
#     docker-compose -f docker-compose-dind.yml create
