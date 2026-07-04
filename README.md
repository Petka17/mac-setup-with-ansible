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

# 3. Clone, set machine-local vars, run
git clone https://github.com/petka17/mac-setup-with-ansible.git
cd ./mac-setup-with-ansible
cp local.example.yml local.yml   # then edit: profile + git identity
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

Tag subsets are for **updating an already-provisioned machine**. A fresh machine
must do a full run first (`./bootstrap.sh` with no tags): tagged areas assume the
base layer is already in place — `stow` from the `term` tag, `neovim` and the Go
toolchain from `mise` — so something like `--tags nvim` on a bare machine fails.

The sudo password is prompted on **every** run, even for tag subsets that never
escalate — `vars_prompt` in `main.yml` runs before Ansible knows which tasks are
selected. Just enter it; only tasks that actually need root use it.

You can also pass any other `ansible-playbook` flag straight through, e.g. `./bootstrap.sh --check` for a dry run.

## Machine profiles & local vars

Two profiles exist: `personal` (the default) and `work`. The work profile skips
personal-only areas (pass/gnupg, skhd, ledger, grok, veracrypt, aws, mac_apps)
and installs a smaller browser set. Profile-scoped lists live in the committed
`vars/personal.yml` and `vars/work.yml`.

Machine-scoped settings — which profile this box runs, plus your git identity
(written to `~/.gitconfig.local`, which the stowed `.gitconfig` includes) —
live in a gitignored `local.yml`. Once per machine, after cloning:

```bash
cp local.example.yml local.yml   # then edit profile + git identity
```

`bootstrap.sh` passes the file on every run, so the choice can't be forgotten
on re-runs. Without a `local.yml` the playbook fails fast with a pointer to
`local.example.yml` — the git identity has no sensible default. To skip an
area on the work profile, add `when: profile == 'personal'` to its
`import_tasks` line in `main.yml`.

## Layout

```plain
mac-setup-with-ansible/
├── bootstrap.sh           # mise + venv + Ansible bootstrap, then runs the playbook
├── main.yml               # play: imports each task file, in order
├── local.example.yml      # template for gitignored local.yml (profile, git identity)
├── vars/                  # profile-scoped vars: personal.yml, work.yml
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
