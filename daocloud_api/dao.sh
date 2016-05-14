#!/bin/bash

# Configs
Token="token"
curl="/usr/bin/curl -sS"
# Auth
Auth="Authorization: token $Token"

# Build flows
Build_flow="https://openapi.daocloud.io/v1/build-flows"  #代码构建 Build Flow
function get_project_list(){
	$curl "$Build_flow" -H "$Auth" #获取项目列表
}
function get_project_info(){
	ID=$1
	Build_flow_info="$Build_flow/$ID"  #获取单个项目
	$curl -H "$Auth" "$Build_flow_info" 
}
function build_project(){
	ID=$1
	branch=${2-master-init}
	Build_flow_build="$Build_flow/$ID/builds"  #手动构建项目 POST '{"branch":"master-init"}'
	#$curl -X POST -H "$Auth" "$Build_flow_build" -D "\{\"branch\"\:\"$branch\"\}"
	$curl -X POST -H "$Auth" "$Build_flow_build" -D '{"branch":"test-insit"}' 
}

## Apps
App_list="https://openapi.daocloud.io/v1/apps" #获取用户的 app 列表.
function get_app_list(){
	$curl "https://openapi.daocloud.io/v1/apps" -H "$Auth" -sS
}
function get_app_info(){
	app_id=$1
	App_info="$App_list/${app_id}" #App 信息 (GET)
	$curl "$App_info" -H "$Auth"
}
function app_actions(){
	action=$1
	app_id=$2
	action_id=$3
	release_name=$4
	App_start="$App_list/${app_id}/actions/start" #启动 App. (POST)
	App_stop="$App_list/${app_id}/actions/stop" #停止 App (POST)
	App_restart="$App_list/${app_id}/actions/restart" #重启 App (POST)
	App_redeploy="$App_list/${app_id}/actions/redeploy" #重新部署 App (POST) '{"release_name": "v1.0.0"}'
	App_action_status="$App_list/${app_id}/actions/${action_id}" #获取事件信息

	case $action in
		start )	$curl -X POST "$App_start" -H "$Auth"
			;;
		stop )  $curl -X POST "$App_stop" -H "$Auth"
			;;
		restart ) $curl -X POST "$App_restart" -H "$Auth"
			;;
		redeploy ) 
			[[ -z "$release_name" ]] && echo "release_name must be provided."
			$curl -X POST "$App_redeploy" -H "$Auth" \
				-H "Content-Type: application/json" \
				-d '{"release_name": "v1.0.0"}'
			;;
		status ) $curl -X POST "$App_action_status" -H "$Auth"
			;;
			*)
			echo "Error, no actions of $1."
			;;
	esac
}


function gen_code(){
	a=(0 1 2 3 4 5 6 7 8 9 a b c d e f g h i j k l m n o p q r s t u v w x y z)
echo ${a[RANDOM%37]}${a[RANDOM%37]}${a[RANDOM%37]}\
${a[RANDOM%37]}${a[RANDOM%37]}
	# s=$(echo $RANDOM | md5sum | head -c 5)
	# echo ${s}
}
## Error
function Error(){
	case "$1" in
		400) echo "Bad Request – 请求格式错误，请查阅对应的文档条目";;
		401) echo "Bad credentials – access token 过期，或请求的API超过授权";;
		404) echo "Not Found – 调用的 API 不存在，请查看本文档";;
		405) echo "Method Not Allowed – 请求 method 错误， 请查阅对应的文档条目";;
		406) echo "Not Acceptable – 请求不是 json 格式";;
		500) echo "Internal Server Error – 服务器错误，请联系 DaoCloud 客服";;
		503) echo "Service Unavailable – 服务器暂时下线，请稍候重试";;
		*) echo "Error";;
	esac
}

function json(){
	read raw
	echo $raw | \
sed 's/\:\ \[/\:\[\n/g' | \
sed 's/},\ {/}\n\n\n{/g' | \
sed 's/},\ /}\n{/g' | \
sed 's/,\ /,\n/g' |\
sed 's/\]\}/\n\]\}/g' |\
sed 's/[]|{|}|,| |[]//g'
}

info=`get_app_list`
## id
echo $info | json | grep '^"id"'
echo $info | json | grep '^"name"'

# get_project_list