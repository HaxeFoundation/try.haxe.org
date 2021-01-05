FROM frolvlad/alpine-glibc
WORKDIR /srv/program
RUN apk add nodejs npm
RUN npm install --global lix || true
RUN echo "/root/haxe/haxelib" > /root/.haxelib
