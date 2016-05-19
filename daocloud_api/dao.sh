#!/bin/bash
# A tool to handle daocoud api.
# Install [jq](https://stedolan.github.io/jq/) first


# Configs
Token=""

# Auth
Auth="Authorization: token $Token"
BaseURL="https://openapi.daocloud.io"

# Build flows
Build_flow="$BaseURL/v1/build-flows"  #代码构建 Build Flow
function get_project_list(){
  curl -sS "$Build_flow" -H "$Auth" -D project_list.header #获取项目列表
}
function get_project_id_by_id(){
  echo $project_list \
  | jq ".build_flows[] | select( .id | startswith(\"$1\") ) | .id" \
  | tr -d '"' # attention! quote!
}
function get_project_id_by_name(){
  echo $project_list \
  | jq ".build_flows[] | select( .name | startswith(\"$1\") ) | .id" \
  | tr -d '"' # attention! quote!
}
function get_project_id(){
  p_name=$1
  p_sid=$1
  p_id=$(get_project_id_by_id $p_sid | head -n 1)
  [[ -z "$p_id" ]] || { echo $p_id && return 0; }
  
  if [[ -z "$p_id" ]];then
    p_id=$(get_project_id_by_name $a_name)
    [[ -z "$p_id" ]] || { echo $p_id && return 0; }
    if [[ -z "$p_id" ]];then
      echo "There is no this project." 
    return 1;
    fi
  fi
}
function get_project_info(){
  ID=$1
  Build_flow_info="${Build_flow}/${ID}" #获取单个项目
  curl -sS -H "$Auth" "$Build_flow_info" -D project_info.header
}
function build_project(){
  ID=$1
  branch=${2-master}
  Build_flow_build="${Build_flow}/${ID}/builds"  #手动构建项目 POST 
  curl -sS -X POST -H "$Auth" "$Build_flow_build" -d "{\"branch\":\"$branch\"}" -H "Content-type: application/json" -D build_project.header
}

## Apps
App_list="$BaseURL/v1/apps" #获取用户的 app 列表.
function get_app_list(){
  curl -sS "$BaseURL/v1/apps" -H "$Auth" -D app_list.header
}
function get_app_info(){
  app_id=$1
  App_info="$App_list/${app_id}" #App 信息 (GET)
  curl -sS "$App_info" -H "$Auth" -D app_info.header
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
function get_app_id(){
  app_name=$1
  app_sid=$1
  a_id=$(get_app_id_by_id $a_sid | head -n 1)
  [[ -z "$a_id" ]] || { echo $a_id && return 0; }
  
  if [[ -z "$a_id" ]];then
    a_id=$(get_app_id_by_name $a_name)
    [[ -z "$a_id" ]] || { echo $a_id && return 0; }
    if [[ -z "$a_id" ]];then
      echo "There is no this app." 
    return 1;
    fi
  fi
}

function get_app_name_by_id(){
  echo $app_list \
  | jq ".app[] | select( .id | startswith(\"$1\") ) | .name"
}

function app_actions(){
  # action sid/name/action_id [release_name]
  action=$1
  app_sid=$2
  app_name=$2
  app_id=$(get_app_id_by_id $app_sid | head -n 1)

  action_id=$2
  if [[ -z "$action_id" ]]; then
    tmp=$(cut -d '"' -f 4- actions.log|tail -n 1)
    app_id=${tmp:0:36}
    action_id=${tmp:38}
  fi

  if [[ "$action" != 'action' ]];then
    if [[ -z "$app_id" ]];then 
        app_id=$(get_app_id_by_name $app_name)
        if [[ -z "$app_id" ]]; then
          echo "There is no this app." 
          return 1
        fi
      else
        echo "There is no this app." 
        return 1
    fi
  else
    tmp=$(cut -d '"' -f 4- actions.log|egrep ^\"$action_id|head -n 1)
    app_id=${tmp:0:36}
    action_id=${tmp:38}
  fi

  release_name=$3 # $3
  App_start="$App_list/${app_id}/actions/start" #启动 App. (POST)
  App_stop="$App_list/${app_id}/actions/stop" #停止 App (POST)
  App_restart="$App_list/${app_id}/actions/restart" #重启 App (POST)
  App_redeploy="$App_list/${app_id}/actions/redeploy" #重新部署 App (POST) 
  App_action_status="$App_list/${app_id}/actions/${action_id}" #获取事件信息
  
  function log(){
    [[ "$action_id" == 'null' ]] \
    && echo $_return | jq '.' \
    || echo -e "$(get_app_name_by_id $app_id)\t$action\t$action_id\t$app_id" >> actions.log
  }
  case "$action" in
    "start" )
      _return=$(curl -sS -X POST "$App_start" -H "$Auth" -D start.header)
      action_id=$(echo $_return | jq '.action_id')
      log
      ;;
    "stop" )
      _return=$(curl -sS -X POST "$App_stop" -H "$Auth" -D stop.header)
      action_id=$(echo $_return | jq '.action_id')
      log
      ;;
    "restart" )
      _return=$(curl -sS -X POST "$App_restart" -H "$Auth" -D restart.header)
      action_id=$(echo $_return | jq '.action_id')
      log
      ;;
    "redeploy" ) 
      [[ -z "$release_name" ]] && echo "Release name set default to master."
      release_name="master"
      _return=$(curl -X POST "$App_redeploy" -H "$Auth" \
        -H "Content-Type: application/json" \
        -d "{\"release_name\": \"$release_name\"}" \
        -D redeploy.header)
      action_id=$(echo $_return | jq '.action_id')
      log
      ;;
    "action" ) 
      curl -sS "$App_action_status" -H "$Auth" -D action_status.header | jq "."
      ;;
      *)
      echo "Error, no actions of $1."
      ;;
  esac
}

## Error
function Error(){
  case "$1" in
    # 400) echo "Bad Request – 请求格式错误，请查阅对应的文档条目";;
    401) echo "Bad credentials – access token 过期，或请求的API超过授权";;
    # 404) echo "Not Found – 调用的 API 不存在，请查看本文档";;
    # 405) echo "Method Not Allowed – 请求 method 错误， 请查阅对应的文档条目";;
    # 406) echo "Not Acceptable – 请求不是 json 格式";;
    500) echo "Internal Server Error – 服务器错误，请联系 DaoCloud 客服";;
    503) echo "Service Unavailable – 服务器暂时下线，请稍候重试";;
    *) echo "Unknown Error.";;
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
  p_id=$(get_project_id $1)
  [[ -z "$p_id" ]] && { echo "ID wrong!"; return 1;}
  mode=$2
  if [[ "$mode" == '-v' ]]; then
    get_project_info $p_id | jq '.'
  else
    get_project_info $p_id \
    | jq '. | {"Name": .name, "Origin": .src_origin_url, "created_at":.created_at[:19]}'
  fi
}
function _build_project(){
  p_id=$(get_project_id $1)
  [[ -z "$p_id" ]] && { echo "ID wrong!"; return 1;}
  branch=$2
  mode=$3
  [[ -z "$p_id" ]] && echo "ID wrong!"
  if [[ "$mode" == '' ]];then
    build_project $p_id $branch \
    | jq '.|{"Status": .status, "Created_at":.created_at[:19], "tag": .tag}'
  else
    build_project $p_id $branch \
    | jq '.'
  fi
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
  a_id=$(get_app_id $1)
  mode=$2
  if [[ "$mode" == '-v' ]]; then
    get_app_info $a_id | jq '.'
  else
    get_app_info $a_id \
    | jq '. | {"Name": .name,"Stat":.state, "Image": .package.image, "Command":.config.command,"Port":.config.expose_port,"Created_at":.created_at[:19]}'
  fi
}

# other
function _history(){
  mode=$1
  [[ "$mode" == '-v' ]] && cat -n history.log || cat -n history.log | tail -n 5
}

function main(){
  update_list
  while : ; do
    read -p ">_" -e cmd arg1 arg2 arg3
    [[ "$cmd" != "history" ]] && echo "$cmd $arg1 $arg2 $arg3">>history.log
    case "$cmd" in
      "ls")
        case $arg1 in
          "-a" | "a") _list_app $arg2 ;;
          "-b" | "b") _list_project $arg2 ;;
          *) echo "Usage: ls -[a|b] [-v|-vv]" ;;
        esac
        ;;
      "info")
        case $arg1 in
          "-a" | "a") _info_app $arg2 $arg3 ;;
          "-b" | "b") _info_project $arg2 $arg3 ;;
          *) echo "Usage: info -[a|b] [app|build]_name|[app|build]_id [-v]" ;;
        esac
        ;;
      "start" | "stop" | "restart" | "redeploy" | "action")
        case $arg1 in
          "start" | "stop" | "restart" | "redeploy" | "action")
            app_actions $cmd $arg1 $arg2
            update_list
            ;;
          *) echo "Usage: [start|stop|restart|redeploy|action] app_[name|_id]" ;;
        esac
        ;;
      "limits" )
        limits
        ;;
      "history")
        _history $arg1
        ;;
      "actions"|"as")
        cat actions.log | column -t
        ;;
      "c" | "cl" | "clear") echo -e "App Name\tAction\tActionID\tAppID" > actions.log 
        echo -n > history.log
        ;;
      "u" | "update" ) update_list ;;
      "q" | "quit") exit ;;
      \? | "help") echo "Usage:";;
      *) ;;
    esac
  done
}

main