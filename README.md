Setup your Mac with Ansible
===

# Disclaimer
This scripts was designed to run under fresh Mojave installation.

# How to get this project on fresh machine 
In the terminal execute the following commands
```bash
curl -L -O https://github.com/Petka17/mac-setup-with-ansible/archive/master.zip
unzip master.zip
cd mac-setup-with-ansible-master
```
# Prepare
You need to install Command Line Tools, pip and ansible itself.  
In order to do that run `prepare.sh`
> Note: you will need to enter sudo password along the way

# Run Playbook
You need to run
`ansible-playbook mail.yml`

# TODO
1. Install Mac Updates