# Micro docker
FROM nginx 
#FROM ubuntu
MAINTAINER wrfly mr.wrfly@gmail.com

# Install nginx and php
RUN fallocate -l 200M /usr/share/nginx/html/index.html

# Expose port
EXPOSE 80

ENTRYPOINT [ "nginx", "-g", "daemon off;" ]
