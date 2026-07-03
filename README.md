# Bootstrap macOS

Declarative macOS provisioning with Ansible. There are **two** manual steps:

- Xcode Command Line Tools install
- Homebrew install

Everything else — CLI tools, dev toolchain, GUI apps, fonts, and system preferences — is installed and kept up to date by Ansible.

## How it works

The only imperative shell in the whole setup is `bootstrap.sh`, which:

1. Checks that Xcode Command Line Tools are present — they provide `git` and `curl`.
2. Checks that Homebrew is present — the `community.general.homebrew` module manages _packages_ but cannot install Homebrew itself, so that stays a manual step.
3. Installs `mise` via Homebrew (if missing) and uses it to install Python 3.11.
4. Builds an **isolated Ansible** in a venv from that Python.
5. Runs `main.yml` against `localhost`.

From there, `main.yml` includes one task file per concern. `tasks/homebrew.yml` only keeps Homebrew itself up to date — installing it is your job (step 2 below).

## First-time setup

```bash
# 1. Install Xcode Command Line Tools — git + python3 (click through the dialog)
xcode-select --install

# 2. Install Homebrew — https://brew.sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. Clone and run
git clone https://github.com/petka17/mac-setup-with-ansible.git
cd ./mac-setup-with-ansible
./bootstrap.sh
```

The playbook prompts for your sudo password once (`vars_prompt` in `main.yml`) — a few casks use it for post-install steps.

## Updating / running a subset

Each task file carries a tag, so you can install or update just one area instead of the whole machine:

```bash
./bootstrap.sh --tags term          # just terminal CLI tools
./bootstrap.sh --tags nvim,tmux     # Neovim and tmux
./bootstrap.sh --tags defaults      # re-apply macOS preferences
```

The tag for each area is listed next to its `import_tasks` line in `main.yml`.

Run with no tags to do everything. Re-running is safe — every task is idempotent.

The sudo password is prompted on **every** run, even for tag subsets that never
escalate — `vars_prompt` in `main.yml` runs before Ansible knows which tasks are
selected. Just enter it; only tasks that actually need root use it.

You can also pass any other `ansible-playbook` flag straight through, e.g. `./bootstrap.sh --check` for a dry run.

## Layout

```plain
mac-setup-with-ansible/
├── bootstrap.sh           # mise + venv + Ansible bootstrap, then runs the playbook
├── main.yml               # play: imports each task file, in order
├── ansible.cfg
├── tasks/                 # one file per concern, each with a matching tag
│   ├── homebrew.yml       # keeps Homebrew itself up to date (tag: homebrew)
│   ├── macos-defaults.yml # system preferences (tag: defaults)
│   ├── terminal.yml       # CLI utilities incl. stow (tag: term)
│   ├── mise.yml           # dev toolchain versions (tag: mise)
│   └── ...                # one file per tool — see main.yml for the full list
└── dotfiles/              # GNU Stow packages, symlinked into $HOME
```

To add a new area: drop a `tasks/<name>.yml` with its package list inline, and add one tagged `import_tasks` line to `main.yml`.

## Customise

Each task file holds its own package list inline — to add or remove a package, edit the relevant `tasks/<name>.yml`. The lists shipped here are sensible starting points — trim and extend to taste.

## Dotfiles

Configuration files are managed with [GNU Stow](https://www.gnu.org/software/stow/). Stow is installed by `tasks/terminal.yml` before any task that needs it.

```plain
dotfiles/
└── mise/                  # stow package name
    └── .config/
        └── mise/
            └── config.toml
```

The directory tree inside each package mirrors `$HOME`. Running `stow -d dotfiles -t ~ --no-folding <package>` creates a symlink for each file into the correct location — `dotfiles/mise/.config/mise/config.toml` becomes `~/.config/mise/config.toml`.

To add a new tool's config: create `dotfiles/<tool>/<path-relative-to-home>/...` and add a stow task to the relevant task file.

## Manual steps

1. macOS Settings
   - Input sources
   - Caps Lock as Escape
   - Cmd + 1, Cmd + 2, ... Cmd + 9 - switch desktop
   - Off Reduce motion
   - Spotlight indexing
   - Default browser
2. Copy vault and mount it
3. Copy ssh keys
4. Import gpg private key
5. Grant skhd Accessibility permission, then run `skhd --restart-service`
6. Run `colima` when you need it
7. Install browser extentions: Vimium, Measure Everything
