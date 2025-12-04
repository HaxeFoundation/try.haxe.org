FROM ubuntu:noble
RUN export DEBIAN_FRONTEND=noninteractive
RUN ln -fs /usr/share/zoneinfo/Europe/Kiev /etc/localtime
WORKDIR /srv/program
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates build-essential gcc g++ libpcre3 libpcre3-dev git cmake make libpng-dev libopenal-dev libsdl2-dev libmbedtls-dev libuv1-dev libturbojpeg libjpeg-turbo8-dev libvorbis-dev libglu1-mesa-dev nodejs npm
RUN npm i lix --global
RUN lix scope create --global
RUN lix install --global haxe 4.3.7
RUN haxelib setup /root/haxe/haxelib
RUN haxelib install hashlink
CMD rm -rf hashlink; \
    git clone https://github.com/HaxeFoundation/hashlink.git; \
    cd hashlink; \
    cmake .;  \
    make; \
    cp bin/hl bin/libhl.so* bin/*.hdll /hashlink-bin/
