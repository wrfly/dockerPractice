#!/bin/bash
# A tool to handle daocoud api.
# Install [jq](https://stedolan.github.io/jq/) first


# Configs
Token="yourTOKEN"

# Auth
Auth="Authorization: token $Token"
BaseURL="https://openapi.daocloud.io"

# Build flows
Build_flow="$BaseURL/v1/build-flows"  #代码构建 Build Flow
function get_project_list(){
  curl -sS "$Build_flow" -H "$Auth" #获取项目列表
}
function get_project_id_by_id(){
  echo $project_list \
  | jq ".build_flows[] | select( .id | startswith(\"$1\") ) | .id" \
  | tr -d '"' # attention! quote!
}
function get_project_info(){
  ID=$1
  Build_flow_info="${Build_flow}/${ID}" #获取单个项目
  curl -sS -H "$Auth" "$Build_flow_info" 
}
function build_project(){
  ID=$1
  branch=${2-master}
  Build_flow_build="${Build_flow}/${ID}/builds"  #手动构建项目 POST 
  curl -sS -X POST -H "$Auth" "$Build_flow_build" -d "{\"branch\":\"$branch\"}" -H "Content-type: application/json"
}

## Apps
App_list="$BaseURL/v1/apps" #获取用户的 app 列表.
function get_app_list(){
  curl -sS "$BaseURL/v1/apps" -H "$Auth"
}
function get_app_info(){
  app_id=$1
  App_info="$App_list/${app_id}" #App 信息 (GET)
  curl -sS "$App_info" -H "$Auth"
}
function get_app_id_by_name(){
  # by name
  echo $app_list \
  | jq ".app[] | select( .name |startswith(\"$1\" ) ) | .id"  \
  | tr -d '"'
}
function get_app_id_by_id(){
  # by id
  echo $app_list \
  | jq ".app[] | select( .id | startswith(\"$1\") ) | .id"  \
  | tr -d '"'
}
function get_app_name_by_id(){
  echo $app_list \
  | jq ".app[] | select( .id | startswith(\"$1\") ) | .name"
}
function app_actions(){
  # app_action app_id [action/action_id] [release_name]
  app_sid=$1
  app_name=$1
  app_id=$(get_app_id_by_id $app_sid | head -n 1)
  [[ -z "$app_id" ]] && { app_id=$(get_app_id_by_name $app_name) && [[ -z "$app_id" ]] && echo "There is no this app." && return 1; }

  action=$2
  action_id=$2
  release_name=$3 # $3
  App_start="$App_list/${app_id}/actions/start" #启动 App. (POST)
  App_stop="$App_list/${app_id}/actions/stop" #停止 App (POST)
  App_restart="$App_list/${app_id}/actions/restart" #重启 App (POST)
  App_redeploy="$App_list/${app_id}/actions/redeploy" #重新部署 App (POST) 
  App_action_status="$App_list/${app_id}/actions/${action_id}" #获取事件信息
  function log(){
    echo $(get_app_name_by_id $app_id) $action $action_id >> actions.log
  }
  case "$action" in
    "start" )
      action_id=$(curl -sS -X POST "$App_start" -H "$Auth" | jq ".action_id")
      log
      ;;
    "stop" )
      action_id=$(curl -sS -X POST "$App_stop" -H "$Auth" | jq ".action_id")
      log
      ;;
    "restart" )
      action_id=$(curl -sS -X POST "$App_restart" -H "$Auth" | jq ".action_id")
      log
      ;;
    "redeploy" ) 
      [[ -z "$release_name" ]] && echo "release_name must be provided."
      curl -X POST "$App_redeploy" -H "$Auth" \
        -H "Content-Type: application/json" \
        -d "{\"release_name\": \"$release_name\"}"
      ;;
    "status" ) curl -X POST "$App_action_status" -H "$Auth"
      ;;
      *)
      echo "Error, no actions of $1."
      ;;
  esac
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

function update_list(){
  # get lists
  app_list=$(get_app_list)
  project_list=$(get_project_list)
}

# projects
function _list_project(){
  mode=$1
  case $mode in
    -v )
      echo $project_list \
      | jq '.build_flows[] | {"Build Name":.name,"Repo": .repo, "Status": .status, "ID": .id, "Created at": .created_at}'  
      ;;
    -vv)
      echo $project_list | jq
      ;;
    * )
      echo $project_list \
      | jq '.build_flows[] | {"Build Name":.name,"Repo": .repo, "Short ID": .id[0:5] }'
      ;;
  esac
}

function _info_project(){
  p_sid=$1
  mode=$2
  p_id=$(get_project_id_by_id $p_sid)
  [[ -z "$p_id" ]] && echo "ID wrong!" && exit 1
  if [[ "$mode" == '-v' ]]; then
    get_project_info $p_id | jq '.'
  else
    get_project_info $p_id \
    | jq '. | {"Name": .name, "Origin": .src_origin_url, "created_at":.created_at[:19]}'
  fi
}
function _build_project(){
  p_sid=$1
  branch=$2
  mode=$3
  p_id=$(get_project_id_by_id $p_sid)
  if [[ "$mode" == '' ]];then
    build_project $p_id $branch \
    | jq '.|{"Status": .status, "Created_at":.created_at[:19], "tag": .tag}'
  else
    build_project $p_id $branch \
    | jq '.'
  fi
}
function select_project(){
  :
}

# apps
function _list_app(){
  mode=$1
  case $mode in
    -v )
      echo $app_list | jq
      ;;
    * )
      echo $app_list \
      | jq '.app[] | {"Name":.name,"Stat": .state,
      "ID": .id[:5]}'
      ;;
  esac

}
function _info_app(){
  a_sid=$1
  a_name=$1
  mode=$2
  a_id=$(get_app_id_by_id $a_sid | head -n 1)
  [[ -z "$a_id" ]] && { a_id=$(get_app_id_by_name $a_name) && [[ -z "$a_id" ]] && echo "There is no this app." && return 1; }
  if [[ "$mode" == '-v' ]]; then
    get_app_info $a_id | jq '.'
  else
    get_app_info $a_id \
    | jq '. | {"Name": .name,"Stat":.state, "Image": .package.image, "Command":.config.command,"Port":.config.expose_port,"Created_at":.created_at[:19]}'
  fi
}

# other
function _history(){
  :
}


function main(){
  echo -n > actions.log
  update_list
  while : ; do
    read -p ">_" -e cmd arg1 arg2
    case "$cmd" in
      "la")
        _list_app $arg1 $arg2
        ;;
      "lp")
        _list_project $arg1 $arg2
        ;;
      "ip")
        _info_project $arg1 $arg2
        ;;
      "ia")
        _info_app $arg1 $arg2
        ;;
      "start" | "stop" | "restart" | "redeploy")
        app_actions $arg1 $cmd $arg2
        update_list
        ;;
      "actions") tail actions.log
        ;;
      "q")
        exit
        ;;
      *)
        echo "Usage: "
    esac
  done
}


main