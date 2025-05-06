#!/usr/bin/env bash
set -euo pipefail

trap 'error "Script failed at line $LINENO"; exit 1' ERR

### CONFIG ###
APPS=(
  zsh
  neovim
  fzf
  zoxide
  bat
  btop
  fd
  duf
  eza
  ripgrep
  oh-my-posh-bin
)

### HELPERS ###
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

### FUNCTIONS ###

install_paru() {
  if ! command -v paru &>/dev/null; then
    info "Installing paru (AUR helper)..."

    sudo pacman -S --needed --noconfirm git base-devel

    local paru_dir="$HOME/paru"
    local original_dir
    original_dir="$(pwd)"

    # Clean slate
    [[ -d "$paru_dir" ]] && rm -rf "$paru_dir"

    git clone https://aur.archlinux.org/paru.git "$paru_dir"
    cd "$paru_dir"
    makepkg -si --noconfirm

    # Clean up and return
    cd "$original_dir"
    rm -rf "$paru_dir"

    success "paru installed successfully"
  else
    success "paru already installed"
  fi
}

install_app() {
  local app="$1"

  # Check if the app is already installed (via pacman or yay)
  if pacman -Qi "$app" &>/dev/null || yay -Qi "$app" &>/dev/null; then
    success "$app is already installed"
    return
  fi

  # Search for the app in pacman
  info "Searching for $app in pacman..."
  if pacman -Ss "$app" &>/dev/null; then
    info "$app found in pacman — installing..."
    if sudo pacman -S --noconfirm "$app"; then
      success "Installed $app via pacman"
      return
    fi
  fi

  # If not found in pacman, try yay
  warn "$app not found in pacman — trying paru..."
  if paru -S --noconfirm "$app"; then
    success "Installed $app via yay"
    return
  fi

  # If both fail, report an error
  error "Failed to install $app with both pacman and yay"
}

append_to_zshenv() {
  echo "[DEBUG] append_to_zshenv function started"
  echo "[DEBUG] Current user: $(whoami)"

  local zshenv_path="/etc/zsh/zshenv"
  echo "[DEBUG] zshenv_path=$zshenv_path"
  # shellcheck disable=SC2016
  local block='
if [[ -z "$XDG_CONFIG_HOME" ]]; then
  export XDG_CONFIG_HOME="$HOME/.config"
fi

if [[ -z "$XDG_DATA_HOME" ]]; then
  export XDG_DATA_HOME="$HOME/.local/share"
fi

if [[ -z "$XDG_CACHE_HOME" ]]; then
  export XDG_CACHE_HOME="$HOME/.cache"
fi

if [[ -z "$XDG_RUNTIME_DIR" ]]; then
  export XDG_RUNTIME_DIR="/run/user/$UID"
fi

if [[ -z "$XDG_LOG_DIR" ]]; then
  export XDG_LOG_DIR="$HOME/.cache/logs"
fi

if [[ -z "$XDG_STATE_HOME" ]]; then
  export XDG_STATE_HOME="$HOME/.local/state"
fi

if [[ -d "$XDG_CONFIG_HOME/zsh" ]]; then
  export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
fi
# cargo home , rustup home and go home
if [[ -z "$CARGO_HOME" ]]; then
  export CARGO_HOME="$XDG_DATA_HOME/cargo"
fi

if [[ -z "$RUSTUP_HOME" ]]; then
  export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
fi

if [[ -z "$GO_HOME" ]]; then
  export GO_HOME="$XDG_DATA_HOME/go"
fi

if [[ -z "$GOPATH" ]]; then
  export GOPATH="$GO_HOME"
fi

'

  if [[ ! -d "/etc/zsh" ]]; then
    info "Creating /etc/zsh directory..."
    sudo mkdir -p /etc/zsh
  fi

  if [[ ! -f "$zshenv_path" ]]; then
    info "Creating $zshenv_path..."
    sudo sh -c "echo '# Created by windots post-install' > '$zshenv_path'"
  fi

  if ! grep -q 'export ZDOTDIR=' "$zshenv_path"; then
    info "Appending ZDOTDIR config..."
    echo "$block" | sudo tee -a "$zshenv_path" >/dev/null
    success "ZDOTDIR config added to $zshenv_path"
  else
    info "ZDOTDIR config already present — skipping"
  fi
}

copy_dotfiles() {
  local source_dir="$PWD/wsl/dotfiles"
  local dest_dir="$HOME/.config"
  echo "[DEBUG] source_dir=$source_dir"
  echo "[DEBUG] dest_dir=$dest_dir"

  # Check if the source directory exists
  if [[ ! -d "$source_dir" ]]; then
    error "Source directory $source_dir does not exist! Aborting."
    return 1
  fi

  # Check if the destination directory exists, create if it doesn't
  if [[ ! -d "$dest_dir" ]]; then
    info "Creating $dest_dir..."
    mkdir -p "$dest_dir"
  fi

  # Loop through all files and directories in the source directory
  info "Copying dotfiles from $source_dir to $dest_dir..."
  for item in "$source_dir"/*; do
    local item_name
    item_name=$(basename "$item")

    if [[ -f "$item" ]]; then
      # If it's a file, copy it to the destination
      if [[ ! -e "$dest_dir/$item_name" ]]; then
        info "Copying file: $item_name"
        cp -v "$item" "$dest_dir/"
      else
        info "File $item_name already exists in $dest_dir — skipping."
      fi
    elif [[ -d "$item" ]]; then
      # If it's a directory, copy it recursively to the destination
      if [[ ! -e "$dest_dir/$item_name" ]]; then
        info "Copying directory: $item_name"
        cp -r -v "$item" "$dest_dir/"
      else
        info "Directory $item_name already exists in $dest_dir — skipping."
      fi
    fi
  done

  success "Dotfiles copied to $dest_dir successfully."
}

set_zsh_as_default_shell() {
  if [[ "$SHELL" != "$(which zsh)" ]]; then
    info "Changing default shell to zsh..."
    chsh -s /usr/bin/zsh
    success "Default shell changed to zsh"
  else
    success "Default shell is already zsh"
  fi
}

change_root_shell() {
  info "Changing root shell to zsh..."
  sudo chsh -s /usr/bin/zsh root
  info "linking .config to /root/.config"
  sudo ln -s "$HOME/.config" /root/.config
  info "linking antidote cache to /root/.cache"
  sudo ln -s "$HOME/.cache/antidote" /root/.cache/
  success "Root shell changed to zsh"
}

load_themes() {
  zsh -i -c "
    source '/home/$USER/.config/zsh/.zshrc';
    antidote load;
  "
}

## EXECUTION ###
install_paru
copy_dotfiles

for app in "${APPS[@]}"; do
  install_app "$app"
done

append_to_zshenv
set_zsh_as_default_shell
change_root_shell
load_themes
success "✅ Post-installation complete!"

if [[ -f /etc/wsl-distribution.conf ]]; then
  sudo sed -i 's/^\(command *=.*\)/# \1/' /etc/wsl-distribution.conf
  success "Hushed login message"
  info "Shutting down WSL to apply changes..."
  powershell.exe -Command "wsl --shutdown"

else
  warn "/etc/wsl-distribution.conf not found. Skipping..."
fi
