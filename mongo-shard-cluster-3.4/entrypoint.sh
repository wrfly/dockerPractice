#!/bin/bash

# portcheck
sleep 1 && /portcheck

# generate mongo_key
touch /etc/mongo_key
chmod 600 /etc/mongo_key
echo -n "$MONGODB_USERNAME:$MONGODB_PASSWORD" | md5sum | head -c30 > /etc/mongo_key
chown mongodb /etc/mongo_key

if [ "${1:0:1}" = '-' ]; then
    set -- mongod "$@"
fi

# allow the container to be started with `--user`
# all mongo* commands should be dropped to the correct user
if [[ "$1" == mongo* ]] && [ "$(id -u)" = '0' ]; then
    if [ "$1" = 'mongod' ]; then
        chown -R mongodb /data/configdb /data/db
    fi
    exec gosu mongodb "$BASH_SOURCE" "$@"
fi

# you should use numactl to start your mongod instances, including the config servers, mongos instances, and any clients.
# https://docs.mongodb.com/manual/administration/production-notes/#configuring-numa-on-linux
if [[ "$1" == mongo* ]]; then
    numa='numactl --interleave=all'
    if $numa true &> /dev/null; then
        set -- $numa "$@"
    fi
fi

# if lock exist, just exec command, won't init cluster
if [[ -f "/data/db/.init.lock" ]]; then
    exec "$@"
fi

if [[ "$PRIMARY" == "1" ]] || [[ "$CONFIG" == "1" ]] || [[ "$MONGOS" == "1" ]]; then
    (exec "$@") &
    RET=1
    while [[ RET -ne 0 ]]; do
        echo "=> Waiting for MongoDB service startup"
        sleep 5
        mongo admin --eval "help" >/dev/null 2>&1
        RET=$?
    done

    # rs number
    N=$RS
    
    # normal mongodb
    if [[ "$PRIMARY" == "1" ]]; then
mongo admin << EOF
rs.initiate(
  { 
    _id:"rs${N}",
    members:[
    {_id:0,host:"mongod_s${N}r1:27017"},
    {_id:1,host:"mongod_s${N}r2:27017"},
    {_id:2,host:"mongod_s${N}r3:27017",arbiterOnly:true}
    ]
  }
);
EOF

# setting password
    is_primary=0
    while [[ $is_primary -eq 0 ]]; do
        echo "=> Waiting node to be primary.."
        sleep 2
        state=$(mongo --eval 'rs.status().members[0].stateStr' | tail -1)
        if [[ "$state" == "PRIMARY" ]]; then
            is_primary=1
        fi
    done
mongo admin << EOF
    admin = db.getSiblingDB("admin")
    admin.createUser(
      {
        user: "$MONGODB_USERNAME",
        pwd: "$MONGODB_PASSWORD",
        roles: [ "root" ]
      }
    );
EOF
    fi

    # mongo config server
    if [[ "$CONFIG" == "1" ]]; then
mongo admin << EOF
    rs.initiate(
      {
        _id:"rs${N}",
        configsvr: true,
        members: [
        {_id:0,host:"mongoc1:27017"},
        {_id:1,host:"mongoc2:27017"},
        {_id:2,host:"mongoc3:27017"}
        ]
      }
    );
EOF
    fi

    # mongos settings
    if [[ "$MONGOS" == "1" ]]; then
        if [[ "$S_PRIMARY" == "1" ]]; then
# create admin
mongo admin << EOF
    admin = db.getSiblingDB("admin")
    admin.createUser(
      {
        user: "$MONGODB_USERNAME",
        pwd: "$MONGODB_PASSWORD",
        roles: [
          { "role": "userAdminAnyDatabase", "db": "admin" },
          { "role" : "clusterAdmin", "db" : "admin" },
          "root"
        ]
      }
    );
EOF
sleep 5
    # add shard with auth
mongo admin -u $MONGODB_USERNAME -p $MONGODB_PASSWORD << EOF
db.runCommand( { enablesharding :"${DEFAULTDB:-defaultdb}"});
db.runCommand( { shardcollection : "${DEFAULTDB:-defaultdb}.${DEFAULTC:-default_collection}",key : {id: 1} } );
use ${DEFAULTDB:-defaultdb};
for (var i = 1; i <= 100; i++) { db.${DEFAULTC:-default_collection}.save({id:i,"test1":"testval1"}); };
db.${DEFAULTC:-default_collection}.stats()["sharded"];
EOF
        fi
    # add shard without auth
mongo admin << EOF
    db.runCommand(
        { addshard : "rs${N}/mongod_s${N}r1:27017,mongod_s${N}r2:27017,mongod_s${N}r3:27017"});
EOF
sleep 5
    # add shard with auth
mongo admin -u $MONGODB_USERNAME -p $MONGODB_PASSWORD << EOF
    db.runCommand(
        { addshard : "rs${N}/mongod_s${N}r1:27017,mongod_s${N}r2:27017,mongod_s${N}r3:27017"});
EOF
# check command
# db.runCommand( { listshards : 1 } );
# check command
    fi
    touch /data/db/.init.lock
# it's no use for `fg`
while [[ 1 ]]; do
    sleep 999
done
else
    touch /data/db/.init.lock
    exec "$@"
fi
