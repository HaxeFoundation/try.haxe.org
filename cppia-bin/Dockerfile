FROM ubuntu:jammy
RUN export DEBIAN_FRONTEND=noninteractive
RUN ln -fs /usr/share/zoneinfo/Europe/Kiev /etc/localtime
WORKDIR /srv/program
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates build-essential gcc g++ git nodejs npm
RUN npm i lix --global
RUN lix scope create --global
RUN lix install --global haxe 4.3.7
RUN haxelib setup /root/haxe/haxelib
CMD rm -rf hxcpp; \
    git clone https://github.com/HaxeFoundation/hxcpp.git --depth=1 --single-branch; \
	haxelib dev hxcpp hxcpp; \
	haxe -C hxcpp/tools/hxcpp compile.hxml; \
    haxe -C hxcpp/project compile-cppia.hxml;  \
    cp hxcpp/bin/Linux64/Cppia /cppia-bin/
