Setup your Mac with Ansible
===

# Disclaimer
This scripts was designed to run under fresh Mojave installation.

# How to get this project on fresh machine 
In the terminal execute the following commands
```bash
git clone https://github.com/petka17/mac-setup-with-ansible
cd mac-setup-with-ansible
```
# Prepare
You need to install Command Line Tools, pip and ansible itself.  
In order to do that run `prepare.sh`
> Note: you will need to enter sudo password along the way

# Run Playbook
You need to run
`ansible-playbook mail.yml`

# secrets.yml format
```
---
keys:
  private:
    path: ~/.ssh/id_rsa
    content: |
      -----BEGIN RSA PRIVATE KEY-----
      your private key
      -----END RSA PRIVATE KEY-----
  public:
    path: ~/.ssh/id_rsa.pub
    content: <your_public_key>
ssh_config: |
  <your_ssh_config>
git:
  name: <name_for_commit>
  email: <email_for_commit>
  signingkey: <signingkey>
  github:
    user: <your_github_account>
    token: <your_github_token>
```

# Test with vagrant
Install Virtualbox, vagrant and vagrant disksize plugin
```
brew cask install virtualbox 
brew install vagrant
vagrant plugin install vagrant-disksize
```
