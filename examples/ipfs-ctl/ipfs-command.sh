#!/bin/bash

set -e

. ../../vars.sh

COMMAND_FILE=ipfs

CMD_PATH="${SIM_SHARED_HOST_DIR}/${COMMAND_FILE}"

usage() {
  echo Usage: "$0 <command> <args...>"
  echo
  echo Commands:
  echo "  exec-all   <ipfs command>                - Execute an IPFS command on all nodes and returns the command ID"
  echo "  exec-one   <LXC name>     <ipfs command> - Execute an IPFS command on the specified node and returns the command ID"
  echo "  get-output <command ID>   <LXC name>     - Retrieve the stdout given for command ID on given LXC"
  echo "  status     <command ID>   <LXC name>     - Displays status of given command ID on all LXCs"
  exit 1
}

exec_all() {
  CMD=$@
  echo "$CMD" >"${CMD_PATH}.new"
  mv "${CMD_PATH}.new" "${CMD_PATH}"
  CMD_ID=$(echo -n "$(stat --format=%Y "${CMD_PATH}")${CMD}"|sha1sum|cut -d' ' -f1)
  echo $CMD_ID 
}

exec_one() {
  LXC=$1
  shift
  CMD=$@
  echo "$CMD" >"${CMD_PATH}.${LXC}.new"
  mv "${CMD_PATH}.${LXC}.new" "${CMD_PATH}.${LXC}"
  CMD_ID=$(echo -n "$(stat --format=%Y "${CMD_PATH}.${LXC}")${CMD}"|sha1sum|cut -d' ' -f1)
  echo $CMD_ID 
}

get_output() {
  CMD_ID=$1
  LXC=$2

  sed -E "/IPFS-EXEC OUTPUT ${CMD_ID}\$/,/IPFS-EXEC DONE ${CMD_ID}\$/"'!d' "${SIM_SHARED_HOST_DIR}/${LXC}/ipfs.log" | head -n -1 | tail -n +2
}

status() {
  CMD_ID=$1
  LXC=$2

  LAST_LINE=$(grep -E ' IPFS-EXEC (START|OUTPUT|DONE) '"${CMD_ID}"\$ "${SIM_SHARED_HOST_DIR}/${LXC}/ipfs.log" | tail -n 1 | cut -d' ' -f1,3)
    echo "${LAST_LINE}"
}

ACTION=$1

case "$ACTION" in
  exec-all)
    shift
    exec_all $@
  ;;
  exec-one)
    shift
    LXC=$1
    shift
    exec_one "$LXC" $@
  ;;
  get-output)
    get_output "$2" "$3"
  ;;
  status)
    status "$2" "$3"
  ;;
  *)
    usage
  ;;
esac
