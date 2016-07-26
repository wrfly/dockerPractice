# Micro docker
FROM ubuntu
#FROM ubuntu
MAINTAINER wrfly mr.wrfly@gmail.com

# Install nginx and php
RUN apt-get update && apt-get -y nginx
RUN fallocate -l 200M /usr/share/nginx/html/index.html

# Expose port
EXPOSE 80

ENTRYPOINT [ "nginx", "-g", "daemon off;" ]
