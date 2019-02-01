#!/usr/bin/env bash

# Prepare to install Command Line Tools
touch "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

echo "-> Check whether Command Line Tools are installed"
pkg_name=`softwareupdate -l | grep -B 1 -E 'Command Line Tools' | awk -F'*' '/^ +\*/ {print $2}' | sed 's/^ *//' | grep -iE '[0-9|.]' | sort | tail -n1`

if [[ $pkg_name != '' ]]; then
    echo "-> Install ${pkg_name}"
    softwareupdate -i "${pkg_name}"
fi

# Cleanup
rm -f "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

echo "-> Install Pip and Ansible"
sudo -- sh -c "easy_install pip; pip install ansible"
