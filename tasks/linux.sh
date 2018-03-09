#!/bin/bash

## First determine if we have the Puppet agent
if which puppet; then
  PUPPET=present
  PUPPET_PATH=$(which puppet)
elif [ -f /opt/puppetlabs/bin/puppet ]; then
  PUPPET=present
  PUPPET_PATH=/opt/puppetlabs/bin/puppet
fi

# Figure out what OS we're on
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_FAMILY=$ID_LIKE
  OS=$ID
  OS_VERSION=$VERSION_ID
else
  # Debian <7 didn't have a os-release file
  if [ -f /etc/debian_version ]; then
    OS_FAMILY="debian"
    OS="debian"
    OS_VERSION=$(cat /etc/debian_version)
  fi
  
  if [ -f /etc/redhat-release ]; then
    OS_FAMILY="redhat"
    OS="redhat"
    OS_VERSION=$(cat /etc/redhat-release)
  fi
fi

## Figure out which init system to use
case $OS in
"debian")
  case $OS_VERSION in
    ^[1-7].*)
      INIT="init"
      ;;
    *)
      INIT="systemd"
  esac
  ;;

"ubuntu")
  case $OS_VERSION in
    ^[00-14].*)
      INIT="init"
      ;;
    *)
      INIT="systemd"
  esac
  ;;
  
"centos")
  case $OS_VERSION in
    ^[1-6].*)
      INIT="init"
      ;;
    *)
      INIT="systemd"
  esac
  ;;

"redhat")
  case $OS_VERSION in
    ^[1-6].*)
      INIT="init"
      ;;
    *)
      INIT="systemd"
  esac
  ;;

esac

puppet_get_param() {
  CMD_PREFIX="$PUPPET_PATH resource service "
  value=`$CMD_PREFIX $PT_name --to-yaml | grep $1 | awk "gsub(/'/, \"\", \$2)" | awk '{ print $2 }'`

  return $value
}

puppet_get_enable() {
  return puppet_get_param "enable"
}

puppet_get_status() {
  return puppet_get_param "ensure"
}

error() {
  "{ status: 'failure'}"
}

puppet_service_action() {
  CMD_PREFIX="$PUPPET_PATH resource service "

  case $1 in
    "start")
      $CMD_PREFIX ensure=running
      if [ $? -eq 0 ]; then
        status='{ status: "started" }'
      else
        status=error
      fi

      return $status
      ;;

    "stop")
      $CMD_PREFIX ensure=stopped
      if [ $? -eq 0]; then
        status="{ status: stopped }"
      else
        status=error
      fi
      ;;

    "restart")
      $CMD_PREFIX ensure=stopped
      if [ $? -eq 0]; then
        status="{ status: stopped }"
      else
        status=error
      fi

      $CMD_PREFIX ensure=running
      if [ $? -eq 0 ]; then
        status="{ status: restarted }"
      else
        status=error
      fi

      return $status
      ;;

    "disable")
      $CMD_PREFIX enable=false

      if [ $? -eq 0 ]; then
        status="{ status: disabled }"
      else
        status=error
      fi

      return $status
      ;;

    "enable")
      $CMD_PREFIX enable=true

      if [ $? -eq 0 ]; then
        status="{ status: enabled }"
      else
        status=error
      fi

      return $status
      ;;

    "status")
      "FIX ME"
      ;;
  esac
}

bash_service_action() {
  case $INIT in
  "systemd")
    /bin/systemd $PT_action $PT_name
    ;;
  "init")
    /usr/sbin/service $PT_NAME $PT_action
    ;;
  esac
}

if [ "$PUPPET" = "present" ]; then
  status=puppet_service_action $PT_action
else
  status=bash_service_action $PT_action
fi
