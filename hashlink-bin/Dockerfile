FROM frolvlad/alpine-glibc
WORKDIR /srv/program
RUN apk add --no-cache ca-certificates build-base gcc g++ pcre pcre-dev git cmake make libpng-dev openal-soft-dev sdl2-dev mbedtls-dev libuv-dev libjpeg-turbo-dev libvorbis-dev glu-dev nodejs npm
RUN npm i lix --global
RUN lix scope create --global
RUN lix install --global haxe 4.1.5
RUN haxelib setup /root/haxe/haxelib
RUN haxelib install hashlink
CMD rm -rf hashlink; \
    git clone https://github.com/HaxeFoundation/hashlink.git; \
    cd hashlink; \
    cmake .;  \
    make; \
    cp bin/hl bin/libhl.so* bin/*.hdll /hashlink-bin/
