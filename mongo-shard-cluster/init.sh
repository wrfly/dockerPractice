#!/bin/bash

# init replica set
for N in {1..3};do
	mongo mongod_s${N}r1:27017/admin << EOF
	config = { _id:"shard${N}", members:[{_id:0,host:"mongod_s${N}r1:27017"},{_id:1,host:"mongod_s${N}r2:27017"},{_id:2,host:"mongod_s${N}r3:27017",arbiterOnly:true}]}
	rs.initiate(config);
	EOF
done

# init sharding
for N in {1..3};do
	mongo mongos${N}:27017/admin << EOF
	db.runCommand( { addshard : "shard${N}/mongod_s${N}r1:27017,mongod_s${N}r2:27017,mongod_s${N}r3:27017"});
	EOF
done

# check status
for N in {1..3};do
	mongo mongos${N}:27017/admin << EOF
	db.runCommand( { listshards : 1 } );
	EOF
done


# # # # # # #
# TEST CASE #
# # # # # # #

# Connect to mongos
# mongo admin

# 指定testdb分片生效
# db.runCommand( { enablesharding :"testdb"});

# 指定数据库里需要分片的集合和片键
# db.runCommand( { shardcollection : "testdb.table1",key : {id: 1} } )

# switch to testdb
# use testdb

# insert docs
# for (var i = 1; i <= 1000; i++) { db.table1.save({id:i,"test1":"testval1"}); }

# check sharded status
# db.table1.stats()["sharded"]