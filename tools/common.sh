#!/bin/bash

export TOOLS_HOME=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Setup git
function setup_git()
{
    git config --global --get user.name || \
        git config --global user.name "$USER"
    git config --global --get user.email || \
        git config --global user.email "$USER@redhat.com"
}

function install_rvm_ruby()
{
  echo "not implemented, please install ruby 2.2.2+ manually"
  # see http://10.66.129.213/index.php/archives/372/ for RHEL notes
  return 1
}
#################################################
############ system-wide functions ##############
#################################################

# Prints operating system 
function os_type()
{
    if [ -f /etc/issue ]; then
        if cat /etc/issue | grep -iq 'fedora'; then
          version=`sed -rn 's/^.*edora release ([0-9]+) .*$/\1/p' < /etc/issue`
          if [ $version -ge 22 ]; then
            echo fedora22 ; return 0
          else
            echo fedora ; return 0
          fi
        fi
        cat /etc/issue | grep -i 'debian' >/dev/null && { echo "debian"; return 0; }
        cat /etc/issue | grep -i 'ubuntu' >/dev/null && { echo "ubuntu"; return 0; }
        cat /etc/issue | grep -i 'Red Hat Enterprise Linux Server release 7' >/dev/null && { echo "rhel7"; return 0; }
        cat /etc/issue | grep -i 'Red Hat Enterprise Linux Server release 6' >/dev/null && { echo "rhel6"; return 0; }
        cat /etc/issue | grep -i 'mint' >/dev/null && { echo "mint"; return 0; }
    fi
    echo 'ERROR: Unsupported OS type'
}

# Will return the method of installing system packages: DEB/YUM
function os_pkg_method()
{
  if [ "$(os_type)" == "fedora22" ]; then
    echo DNF
  elif [ "$(os_type)" == "fedora" ] || [[ "$(os_type)" =~ "rhel" ]]; then
    echo "YUM"
  elif [ "$(os_type)" == "ubuntu" ] || [ "$(os_type)" == "debian" ] || [ "$(os_type)" == "mint" ]; then
    echo "DEB"
  else
    echo "TAR"
  fi
}

# Return 'sudo' if the user's not root
function need_sudo()
{
    if [ `id -u` == "0" ]; then
        echo ''
    else
        echo 'sudo'
    fi
}

# Setup sudo configuration
function setup_sudo()
{
    $(need_sudo) grep CUCUSHIFT_SETUP /etc/sudoers && return
    $(need_sudo) cat > /etc/sudoers <<END
# CUCUSHIFT_SETUP #
Defaults    env_reset
Defaults    env_keep =  "COLORS DISPLAY HOSTNAME HISTSIZE INPUTRC KDEDIR LS_COLORS"
Defaults    env_keep += "MAIL PS1 PS2 QTDIR USERNAME LANG LC_ADDRESS LC_CTYPE"
Defaults    env_keep += "LC_COLLATE LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES"
Defaults    env_keep += "LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE"
Defaults    env_keep += "LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY"

Defaults    secure_path = /usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

root    ALL=(ALL)       ALL
%wheel  ALL=NOPASSWD: ALL
# CUCUSHIFT_SETUP #
END
}

function random_email()
{
    echo "cucushift+$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 10)@redhat.com"
}

function get_random_str()
{
    LEN=10
    [ -n "$1" ] && LEN=$1
    echo "$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c $LEN)"
}
