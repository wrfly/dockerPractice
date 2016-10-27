#!/bin/sh

host=$MYSQL_PORT_3306_TCP_ADDR
pass=$MYSQL_PASSWORD
user=$MYSQL_USERNAME
db=$MYSQL_INSTANCE_NAME

sed -i "s/mysqlhost/$host/" /www/index.php
sed -i "s/mysqluser/$user/" /www/index.php
sed -i "s/mysqlpass/$pass/" /www/index.php
sed -i "s/mysqldb/$db/" /www/index.php

echo "Mysql: host: $host pass: $pass user: $user dbname: $db"

cp /www/htaccess /www/data/.htaccess

httpd

tail -f /var/log/apache2/error.log /var/log/apache2/access.log
