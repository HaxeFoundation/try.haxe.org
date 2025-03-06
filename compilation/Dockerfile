FROM ubuntu:jammy
RUN export DEBIAN_FRONTEND=noninteractive
RUN ln -fs /usr/share/zoneinfo/Europe/Kiev /etc/localtime
RUN dpkg --add-architecture i386
RUN apt-get update && apt-get install -y -o APT::Immediate-Configure=0 lib32gcc-s1 libgc-dev:i386 zlib1g:i386 libpcre3:i386
RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    npm \
    wget
RUN npm install --global lix || true
RUN cd /tmp && wget https://github.com/HaxeFoundation/neko/releases/download/v2-3-0/neko-2.3.0-linux.tar.gz && tar xvfz neko-2.3.0-linux.tar.gz
RUN apt-get remove -y npm wget
RUN apt-get -y autoremove
RUN mv /tmp/neko-v2-0/bin/* /lib/i386-linux-gnu/
RUN rm -rf /tmp/neko*
RUN chown 755 /tmp

# Create a group and user
RUN useradd -ms /bin/bash haxer
RUN chown haxer:haxer /home/haxer
# RUN addgroup haxer && adduser --ingroup haxer haxer

# Tell docker that all future commands should run as the appuser user
USER haxer
WORKDIR /home/haxer

# RUN useradd -ms /bin/sh haxer
RUN mkdir /home/haxer/haxelib
RUN echo "/home/haxer/haxelib" > /home/haxer/.haxelib 
