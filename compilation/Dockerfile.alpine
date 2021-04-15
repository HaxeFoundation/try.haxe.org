FROM frolvlad/alpine-glibc
WORKDIR /home/haxer
RUN apk add nodejs npm musl 
RUN npm install --global lix || true

# Create a group and user
RUN addgroup -S haxer && adduser -S haxer -G haxer
# Tell docker that all future commands should run as the appuser user
USER haxer

# RUN useradd -ms /bin/sh haxer
RUN echo "/home/haxer/haxelib" > /home/haxer/.haxelib 
