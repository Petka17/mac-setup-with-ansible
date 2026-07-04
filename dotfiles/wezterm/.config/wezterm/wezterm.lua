local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

config.font = wezterm.font 'JetBrainsMono Nerd Font'
config.font_size = 16.0

config.color_scheme = 'Catppuccin Mocha'

config.enable_tab_bar = false

-- Walk the pane's foreground process tree looking for tmux. A single
-- get_foreground_process_name() is unreliable here: `tmux` runs as a *child* of
-- the login shell, so macOS often reports the root shell instead. Scanning the
-- tree is correct whether WezTerm returns the tmux client or its parent shell.
local function in_tmux(pane)
  local function scan(proc)
    if not proc then return false end
    if ((proc.name or '') .. (proc.executable or '')):lower():find 'tmux' then
      return true
    end
    for _, child in pairs(proc.children or {}) do
      if scan(child) then return true end
    end
    return false
  end
  return scan(pane:get_foreground_process_info())
end

-- Picker keybindings, triggered at the terminal level so they fire over ANY
-- foreground program (Claude Code, dev servers, nvim) and even before any tmux
-- session exists.
--   * inside tmux -> send the prefix chord so tmux's display-popup renders over
--                    whatever is in the pane (see the matching bind in tmux.conf)
--   * otherwise   -> type the command at the shell
local function tmux_chord(key, fallback_cmd)
  return wezterm.action_callback(function(window, pane)
    if in_tmux(pane) then
      window:perform_action(act.SendKey { key = 'a', mods = 'CTRL' }, pane)
      window:perform_action(act.SendKey { key = key, mods = 'CTRL' }, pane)
    else
      window:perform_action(act.SendString(fallback_cmd .. '\n'), pane)
    end
  end)
end

config.keys = {
  { key = 'f', mods = 'CTRL', action = tmux_chord('f', 'sesh-picker.sh') },
  -- git worktree picker (see `bind C-g` in tmux.conf); its tmux-session
  -- juggling assumes it runs inside tmux, hence no bare-shell shortcut beyond
  -- typing the command.
  { key = 'g', mods = 'CTRL', action = tmux_chord('g', 'worktree-picker.sh') },
}

return config
