FROM ubuntu:jammy
RUN export DEBIAN_FRONTEND=noninteractive
RUN ln -fs /usr/share/zoneinfo/Europe/Kiev /etc/localtime
WORKDIR /srv/program
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates build-essential gcc g++ libpcre3 libpcre3-dev git cmake make libpng-dev libopenal-dev libsdl2-dev libmbedtls-dev libuv1-dev libturbojpeg libjpeg-turbo8-dev libturbojpeg0-dev libvorbis-dev libglu1-mesa-dev nodejs npm wget
RUN wget https://github.com/libsdl-org/SDL/releases/download/release-3.4.16/SDL3-3.4.16.tar.gz
RUN tar xvfz SDL3-3.4.16.tar.gz
RUN cd SDL3-3.4.16; cmake -DSDL_X11_XTEST=OFF --install-prefix=/usr; make; make install
RUN npm i lix --global
RUN lix scope create --global
RUN lix install --global haxe 4.3.7
RUN haxelib setup /root/haxe/haxelib
RUN haxelib install hashlink
CMD rm -rf hashlink; \
    git clone https://github.com/HaxeFoundation/hashlink.git; \
    cd hashlink; \
    cmake .;  \
    mkdir bin; touch bin/openal.hdll; \
    make hl; \
    make libhl; \
    make fmt.hdll; \
    make heaps.hdll; \
    make mysql.hdll; \
    make sdl.hdll; \
    make sqlite.hdll; \
    make ssl.hdll; \
    make ui.hdll; \
    make ub.hdll; \
    cp bin/hl bin/libhl.so* bin/*.hdll /hashlink-bin/
