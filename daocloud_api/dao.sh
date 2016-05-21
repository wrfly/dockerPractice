#!/bin/bash
# A tool to handle daocoud api.
# Install [jq](https://stedolan.github.io/jq/) first


# Configs
token=$1
Token=${token:-bx4ggnf83x0v7rgwyj5dsv2ar4mtfvfzxk9nwuvy}

# Auth
Auth="Authorization: token $Token"
BaseURL="https://openapi.daocloud.io"


## Error
function Error(){
  case "$1" in
    400) echo "Bad Request – 请求格式错误，请查阅对应的文档条目";;
    401) echo "Bad credentials – access token 过期，或请求的API超过授权";;
    404) echo "Not Found – 调用的 API 不存在，请查看本文档";;
    405) echo "Method Not Allowed – 请求 method 错误， 请查阅对应的文档条目";;
    406) echo "Not Acceptable – 请求不是 json 格式";;
    409) echo "Conflict – 请求冲突，请稍后再试";;
    500) echo "Internal Server Error – 服务器错误，请联系 DaoCloud 客服";;
    503) echo "Service Unavailable – 服务器暂时下线，请稍候重试";;
    *) echo "Unknown Error.";;
  esac
}
function checkheader(){
  rcode=$(cat .$1.header | head -n 1 | cut -d ' ' -f 2)
  [[ "$rcode" -ne 200 ]] && Error $rcode && return 2
  return 0
}


# Build flows
Build_flow="$BaseURL/v1/build-flows"  #代码构建 Build Flow
function get_project_list(){
  curl -sS "$Build_flow" -H "$Auth" -D .project_list.header #获取项目列表
}
function get_project_id_by_id(){
  echo $project_list \
  | jq ".build_flows[] | select( .id | startswith(\"$1\") ) | .id" \
  | tr -d '"' | head -n 1 # attention! quote!
}
function get_project_id_by_name(){
  echo $project_list \
  | jq ".build_flows[] | select( .name | startswith(\"$1\") ) | .id" \
  | tr -d '"' | head -n 1 # attention! quote!
}
function get_project_name_by_id(){
  echo $project_list \
  | jq ".build_flows[] | select( .id | startswith(\"$1\") ) | .id" \
  | tr -d '"' | head -n 1 # attention! quote!
}
function get_project_id(){
  p_name=$1
  p_sid=$1
  p_id=$(get_project_id_by_id $p_sid)
  [[ -z "$p_id" ]] || { echo $p_id && return 0; }
  if [[ -z "$p_id" ]];then
    p_id=$(get_project_id_by_name $p_name)
    [[ -z "$p_id" ]] || { echo $p_id && return 0; }
    if [[ -z "$p_id" ]];then
      echo -n ''
      return 1
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
function _list_project(){
  mode=$2
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
  p_id=$1
  mode=$2
  if [[ "$mode" == '' ]]; then
    get_project_info $p_id \
    | jq '. | {"Name": .name, "Origin": .src_origin_url, "created_at":.created_at[:19]}'
  else
    get_project_info $p_id | jq '.'
  fi
}
function _build_project(){
  [[ -z "$1" ]] && { echo "ID wrong!"; return 1;}
  p_id=$(get_project_id $1)
  [[ -z "$p_id" ]] && { echo "ID wrong!"; return 1;}
  branch=${2:-master}
  mode=$3
  echo "Building $(get_project_name_by_id $p_id)... Branch: $branch"
  if [[ "$mode" == '' ]];then
    build_project $p_id $branch \
    | jq '.|{"Status": .status, "Created_at":.created_at[:19], "tag": .tag}'
  else
    build_project $p_id $branch \
    | jq '.'
  fi
}


## Apps
App_list="$BaseURL/v1/apps" #获取用户的 app 列表.
function get_app_list(){
  curl -sS "$BaseURL/v1/apps" -H "$Auth" -D .app_list.header
}
function get_app_info(){
  app_id=$1
  App_info="$App_list/${app_id}" #App 信息 (GET)
  curl -sS "$App_info" -H "$Auth" -D .app_info.header
}
function get_app_id_by_name(){
  # by name
  echo $app_list \
  | jq ".app[] | select( .name |startswith(\"$1\" ) ) | .id"  \
  | tr -d '"' | head -n 1
}
function get_app_id_by_id(){
  # by id
  echo $app_list \
  | jq ".app[] | select( .id | startswith(\"$1\") ) | .id"  \
  | tr -d '"' | head -n 1
}
function get_app_id(){
  app_name=$1
  app_sid=$1
  a_id=$(get_app_id_by_id $app_sid)
  [[ -z "$a_id" ]] || { echo $a_id && return 0; }
  
  if [[ -z "$a_id" ]];then
    a_id=$(get_app_id_by_name $app_name)
    [[ -z "$a_id" ]] || { echo $a_id && return 0; }
  fi
}
function get_app_name_by_id(){
  echo $app_list \
  | jq ".app[] | select( .id | startswith(\"$1\") ) | .name" | head -n 1
}
function app_actions(){
  # action sid/name/action_id [release_name]
  action=$1
  [[ "$2" == '-h' ]] && echo """
  Usage: start [app_short_name|app_short_id]
         stop [app_short_name|app_short_id]
         restart [app_short_name|app_short_id]
         redeploy [app_short_name|app_short_id] [release_name(default master)]
         action [action_short_id]
  """
  app_id=$(get_app_id $2)
  [[ -z $app_id && $action != 'action' ]] && { echo "Wrong ID" && return 1; }
  app_name=$(get_app_name_by_id $app_id)

  function log(){
    [[ "$action_id" == 'null' ]] \
    && echo $_return | jq '.' \
    || echo -e "$(get_app_name_by_id $app_id)\t$action\t$action_id\t$app_id" >> .actions.log
  }
  case "$action" in
    "start"|"stop"|"restart" )
      # App_start="$App_list/${app_id}/actions/start" #启动 App. (POST)
      # App_stop="$App_list/${app_id}/actions/stop" #停止 App (POST)
      # App_restart="$App_list/${app_id}/actions/restart" #重启 App (POST)
      echo "${action}ing $app_name..."
      _return=$(curl -sS -X POST "$App_list/${app_id}/actions/$action" -H "$Auth" -D .$action.header)
      action_id=$(echo $_return | jq '.action_id' 2>/dev/null)
      checkheader $action && log
      ;;
    "redeploy" ) 
      release_name=$3 # $3
      [[ -z "$release_name" ]] && { echo "Release name set default to master.";release_name="master"; }
      echo "Redeploying $app_name, Release name: $release_name..."
      App_redeploy="$App_list/${app_id}/actions/redeploy" #重新部署 App (POST) 
      _return=$(curl -sS -X POST "$App_redeploy" -H "$Auth" \
        -H "Content-Type: application/json" \
        -d "{\"release_name\": \"$release_name\"}" \
        -D .$action.header)
      action_id=$(echo $_return | jq '.action_id' 2>/dev/null)
      { checkheader $action; } && log
      ;;
    "action" )
      action_id=$2
      tmp=$(cut -d '"' -f 4- .actions.log|egrep ^$action_id | tail -n 1)
      [[ -z $tmp ]] && { echo "There's no this action, please check."; return 1; }
      [[ -z "$action_id" ]] && tmp=$(cut -d '"' -f 4- .actions.log|tail -n 1)
      action_id=${tmp:0:36}
      app_id=${tmp:38}

      App_action_status="$App_list/${app_id}/actions/${action_id}" #获取事件信息
      curl -sS "$App_action_status" -H "$Auth" -D .action_status.header | jq "." 2>/dev/null
      checkheader action_status
      ;;
      *)
      echo "Error, no actions of $1."
      ;;
  esac
  _update_list
}
function _list_app(){
  mode=$2
  case $mode in
    -vv )
      echo $app_list | jq
      ;;
    -v )
      echo $app_list \
      | jq '.app[] | {"Name":.name,"Stat": .state,
      "ID": .id[:5], "Image": .package.image, "Created_at":.created_at[:19]}'
      ;;
    * )
      echo $app_list \
      | jq '.app[] | {"Name":.name,"Stat": .state,
      "ID": .id[:5]}'
      ;;
  esac
}
function _info_app(){
  a_id=$1
  mode=$2
  if [[ "$mode" == '' ]]; then
    get_app_info $a_id \
    | jq '. | {"Name": .name,"Stat":.state, "Image": .package.image, "Command":.config.command,"Port":.config.expose_port,"Created_at":.created_at[:19]}'
  else
    get_app_info $a_id | jq '.'
  fi
}


# other
function _update_list(){
  # get lists
  app_list=$(get_app_list)
  project_list=$(get_project_list)
}
function _history(){
  mode=$1
  [[ "$mode" == '-a' ]] && cat -n .history.log || cat -n .history.log | tail -n 5
}
function _limits(){
  echo -e "API\t\tRemaining"
  echo -n > .limits.txt
  for i in .*.header;do
    re=$(cat  $i|grep Remaining | cut -d' ' -f2)
    echo -n ${i//.header} | sed 's/.*/\L&/; s/[a-z]*/\u&/g' | tr -d '.' >> .limits.txt
    echo ": ${re:-Wrong}" >> .limits.txt
  done
  cat .limits.txt | column -t
}
function _ls(){
  opt=$@
  v=0
  local OPTIND opt
  while getopts ":pvh" opt; do
    case $opt in
      p) local PROJECT=1 ;;
      v) let v+=1 ;;
      h)
        echo """
        Usage: ls [-p] [-v|-vv] [id|name]
        Example:
          ls [-v|-vv] [app_short_id|app_short_name]
          ls [-p|-pv|-pvv] [app_short_id|app_short_name]
        """
        return 1
        ;;
      \?)
        echo "Invalid option: -$OPTARG" 
        return 1
        ;;
    esac
  done
  shift $((OPTIND-1))
  sid=$@
  [[ -z "$sid" ]] || local INFO=1
  app_or_project="app"
  [[ "$PROJECT" -eq 1 ]] && app_or_project="project"
  id=$(get_${app_or_project}_id $sid)
  [[ -z $id ]] && { echo "Wrong ID, please check."; return 1; }
  list_or_info="list"
  [[ "$INFO" -eq 1 ]] && list_or_info="info"
  func="_${list_or_info}_${app_or_project}"
  
  [[ "$v" -eq 0 ]] && $func $id
  [[ "$v" -eq 1 ]] && $func $id -v
  [[ "$v" -gt 1 ]] && $func $id -vv
}
function quit(){
  read -p "Really?" -e YN
  [[ "$YN" =~ ^[y|Y]$ ]] && exit 0 || return 0
}
function readline(){
  read -p ">_" -e cmd arg1 arg2 arg3 arg4 arg5
  hcmd=$(echo $cmd $arg1 $arg2 $arg3 $arg4 $arg5)
  [[ -z "$cmd" ]] || history -s "$hcmd"
  if [[ "$cmd" != '' && "$cmd" != "history" ]]; then
    echo "$cmd $arg1 $arg2 $arg3 $arg4 $arg5" >> .history.log
  fi
}

function main(){
  _update_list
  while : ; do
    readline
    case "$cmd" in
      "ls") # List app or projects or get their info
        _ls $arg1 $arg2 $arg3 $arg4 $arg5
        ;;
      "build") # Build project
        _build_project $arg1 $arg2 $arg3 $arg4 $arg5
        ;;
      "start" | "stop" | "restart" | "redeploy" | "action")
        app_actions $cmd $arg1 $arg2 $arg3 $arg4 $arg5
        ;;
      "limits" ) # Get the limits
        _limits
        ;;
      "history") # Get command history
        _history $arg1
        ;;
      "actions") # Get app actions
        cat .actions.log | column -t
        ;;
      "clear"  ) # Clear logs 
        echo -e "App_Name\tAction\tAction_ID\tApp_ID" > .actions.log 
        echo -n > .history.log
        ;;
      "update" ) _update_list ;;
      "q"| "quit")
        quit
        ;;
      \? | "help") echo "Usage: ls, build, [start|stop|restart|redeploy], action, actions, limits, history, clear, update, [quit|q]";;
      *) ;;
    esac
    unset cmd arg1 arg2 arg3 arg4 arg5
  done
}

trap quit INT # disable Ctl-c
touch ls start stop restart action actions limits history help quit update clear redeploy build # auto complete
main