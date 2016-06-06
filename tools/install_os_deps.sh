#!/bin/bash

export TOOLS_HOME=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

. "$TOOLS_HOME"/common.sh

echo "Installing packages on $(os_type)"
if [ "$(os_type)" == "fedora22" ]; then
    cmd="dnf install -y"
    file="deps.dnf.fedora"
elif [ "$(os_type)" == "fedora" ]; then
    cmd="yum install -y"
    file="deps.yum.fedora"
    additional_deps=install_rvm_ruby
elif [ "$(os_type)" == "ubuntu" -o "$(os_type)" == "debian" ] || [ "$(os_type)" == "mint" ]; then
    cmd="apt-get install -q --ignore-missing --fix-missing -y"
    file="deps.deb"
    additional_deps=install_rvm_ruby
elif [ "$(os_type)" == "rhel6" ]; then
    cmd="yum install -y"
    file="deps.yum.RHEL"
    additional_deps=install_rvm_ruby
elif [ "$(os_type)" == "rhel7" ]; then
    cmd="yum install -y"
    file="deps.yum.RHEL7"
    additional_deps=install_rvm_ruby
else
    exit 3
fi

cat ${TOOLS_HOME}/os_deps/$file | grep -v '^\s*#' | xargs $(need_sudo) $cmd
$additional_deps
