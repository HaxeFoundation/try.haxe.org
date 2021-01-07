FROM frolvlad/alpine-glibc
WORKDIR /srv/lixSetup
RUN apk add nodejs npm 
RUN npm install --global lix || true

CMD export HAXESHIM_ROOT=/srv/lixSetup/haxe; \
    lix download; \
    lix install haxe nightly;
