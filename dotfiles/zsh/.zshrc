fpath=(${HOME}/.zsh/completions /opt/homebrew/share/zsh/site-functions /opt/homebrew/share/zsh-completions $fpath)
autoload -Uz compinit && compinit -u
autoload bashcompinit && bashcompinit
complete -C '/opt/homebrew/bin/aws_completer' aws
zstyle ':completion:*' menu select

eval "$(mise activate zsh)"
eval "$(fzf --zsh)"
eval "$(starship init zsh)"

HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000

export NODE_EXTRA_CA_CERTS="$(mkcert -CAROOT)/rootCA.pem" 

# VeraCrypt
alias vcm="veracrypt --mount --pim 0 --keyfiles \"\" --protect-hidden no"
alias vcu="veracrypt --dismount"

# Pass
export PASSWORD_STORE_DIR=~/.m/.pass

# Ledger
export LEDGER_FILE=~/.m/.ledger/main.journal
alias l="hledger"

# Keybinding
bindkey -v

# general
alias ..="cd .."
alias ...="cd ../.."
alias path='echo -e ${PATH//:/\\n}'

# NeoVim
alias v="nvim"

# eza
alias ls='eza --icons'
alias ll='eza -l --icons --git'
alias la='eza -la --icons --git'
alias lt='eza --tree --icons'

# bat
alias cat='bat'

# zoxide — init stays at the end of this file: zoxide hooks the prompt and
# warns (doctor) if anything else, like starship, hooks it after zoxide does.
eval "$(zoxide init zsh)"
alias cd='z'
