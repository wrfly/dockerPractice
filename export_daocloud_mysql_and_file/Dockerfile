FROM mdns/apache2-php:latest
MAINTAINER wrfly mr.wrfly@gmail.com

RUN apk add --update php-mysql php-ldap && \
    echo "ServerName localhost:80" >> /etc/apache2/httpd.conf && \
    rm /www/index.html &&\
    chown apache /www -R

COPY app www

CMD ./www/start.sh
