FROM ubuntu:focal
RUN export DEBIAN_FRONTEND=noninteractive
RUN ln -fs /usr/share/zoneinfo/Europe/Kiev /etc/localtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    npm
WORKDIR /srv/program
RUN npm install --global lix || true
RUN echo "/root/haxe/haxelib" > /root/.haxelib 
# npm only neede to install lix (pulls in a lot of node libs)
RUN apt-get remove npm -y && apt autoremove -y