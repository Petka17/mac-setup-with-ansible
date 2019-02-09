#!/usr/bin/env bash

###
# The first patr of this script was inspired by these ansible tasks 
# https://github.com/elliotweiser/ansible-osx-command-line-tools/blob/master/tasks/main.yml
###

# Check whether CommandLineTools is installed
if [[ ! -d /Library/Developer/CommandLineTools ]]; then
    # Prepare to install Command Line Tools
    touch "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

    echo "-> Getting CommandLineTools package name"
    pkg_name=`softwareupdate -l | grep -B 1 -E 'Command Line Tools' | awk -F'*' '/^ +\*/ {print $2}' | sed 's/^ *//' | grep -iE '[0-9|.]' | sort | tail -n1`

    if [[ $pkg_name != '' ]]; then
        echo "-> Installing ${pkg_name}"
        softwareupdate -i "${pkg_name}"
    fi

    # Cleanup
    rm -f "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
else
    echo "[x] CommandLineTools Installed"
fi

if ! which brew >/dev/null; then
    echo "-> Installing Homebrew"
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
else
    echo "[x] Homebrew installed" 
fi

# Check whether ansible is installed
if ! which ansible >/dev/null; then
    echo "-> Installing Ansible"
    brew install ansible
else
    echo "[x] Ansible installed"
fi
