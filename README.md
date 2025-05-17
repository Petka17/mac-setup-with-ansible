
# Setup your Mac with Ansible

## Disclaimer

This scripts was designed to run under fresh Sequoia installation.

## How to get this project on fresh machine

In the terminal execute the following commands

```sh
git clone https://github.com/petka17/mac-setup-with-ansible
cd mac-setup-with-ansible
```

# Prepare

## Install Homebrew

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## Install ansible

```sh
brew install ansible
```

# Run Playbook

```sh
ansible-playbook mail.yml
```

## Install Rosetta (optional)

```sh
softwareupdate --install-rosetta
```
