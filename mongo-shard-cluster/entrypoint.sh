#!/bin/bash
set -e

# generate mongo_key
touch /etc/mongo_key && \
chmod 600 /etc/mongo_key && \
chown mongodb /etc/mongo_key && \
echo -n "$MONGODB_USER:$MONGODB_PASS" | md5sum | head -c30 > /etc/mongo_key

if [ "${1:0:1}" = '-' ]; then
	set -- mongod "$@"
fi

# allow the container to be started with `--user`
if [ "$1" = 'mongod' -a "$(id -u)" = '0' ]; then
	chown -R mongodb /data/configdb /data/db
	exec gosu mongodb "$BASH_SOURCE" "$@"
fi

if [ "$1" = 'mongod' ]; then
	numa='numactl --interleave=all'
	if $numa true &> /dev/null; then
		set -- $numa "$@"
	fi
fi

exec "$@"
