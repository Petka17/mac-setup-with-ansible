eval "$(/opt/homebrew/bin/brew shellenv)"

# Personal scripts, symlinked here by the `scripts` stow package (tasks/scripts.yml).
# Prepended so they can shadow anything else on PATH. Set in .zprofile (after the
# system /etc/zprofile runs path_helper) so the order isn't reshuffled.
export PATH="$HOME/.local/bin:$PATH"
