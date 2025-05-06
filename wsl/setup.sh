#!/usr/bin/env bash
set -euo pipefail

# Arch Linux WSL Post-Installation Script
# By Victor | Automates setup for WSL-friendly Arch CLI environment

# ====== Color Setup ======
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# ====== Require Root ======
require_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Please run as root${NC}"
    exit 1
  fi
}

# ====== Error Handling ======
error_exit() {
  echo -e "${RED}Error: $1${NC}" >&2
  exit 1
}

# ====== Keyring Setup ======
setup_keyring() {
  echo -e "${YELLOW}Initializing pacman keyring...${NC}"
  pacman-key --init || error_exit "pacman-key init failed"
  pacman-key --populate archlinux || error_exit "pacman-key populate failed"
}

# ====== Locale Config ======
configure_locale() {
  echo -e "${YELLOW}Configuring locale...${NC}"
  sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
  locale-gen || error_exit "locale-gen failed"
  cat >/etc/locale.conf <<EOF
LANG=en_US.UTF-8
LANGUAGE=en_US.UTF-8
LC_ALL=en_US.UTF-8
EOF
  echo -e "${GREEN}Locale configured successfully${NC}"
}

# ====== Pacman Tweaks ======
enable_pacman_option() {
  local opt="$1"
  local val="${2:-}" # Default to empty string if $2 is not provided
  local conf="/etc/pacman.conf"

  if grep -qE "^#?\s*${opt}" "$conf"; then
    if grep -qE "^#\s*${opt}" "$conf" && [[ "$opt" != "NoProgressBar" ]]; then
      sed -i "s|^\s*#\s*${opt}|${opt}|" "$conf"
      echo -e "${GREEN}${opt} uncommented${NC}"
    fi

    if [[ -n "$val" && "$opt" != "NoProgressBar" ]]; then
      sed -i "s|^${opt}.*|${opt} = $val|" "$conf"
      echo -e "${GREEN}${opt} set to ${val}${NC}"
    fi
  else
    echo -e "${YELLOW}${opt} not found, skipping.${NC}"
  fi
}

check_and_enable_ilovecandy() {
  local conf="/etc/pacman.conf"
  if ! grep -qE "^#?\s*ILoveCandy" "$conf"; then
    sed -i "/^\[options\]/a ILoveCandy" "$conf"
    echo -e "${GREEN}ILoveCandy added to pacman.conf${NC}"
  else
    enable_pacman_option "ILoveCandy"
  fi
}
setup_pacman_hooks() {
  echo -e "${YELLOW}Setting up pacman hooks...${NC}"
  local hooks_dir="/etc/pacman.d/hooks"
  local cache_hook_file="$hooks_dir/paccache.hook"
  mkdir -p "$hooks_dir"
  # Pacman Cache Clean Hook
  if [[ -f "$cache_hook_file" ]]; then
    echo -e "${GREEN}Pacman cache clean hook already exists at ${cache_hook_file}${NC}"
  else
    cat <<'EOF' >"$cache_hook_file"
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Cleaning package cache...
When = PostTransaction
Exec = /usr/bin/paccache -rk2 -ruk0
EOF
    echo -e "${GREEN}Pacman cache cleaning hook created at ${cache_hook_file}${NC}"
  fi
}

optimize_pacman() {
  echo -e "${YELLOW}Optimizing pacman.conf...${NC}"

  if grep -qE "^\s*NoProgressBar" /etc/pacman.conf; then
    sed -i "s|^\s*NoProgressBar|#NoProgressBar|" /etc/pacman.conf
    echo -e "${GREEN}NoProgressBar commented out${NC}"
  else
    echo -e "${YELLOW}NoProgressBar not found, skipping.${NC}"
  fi

  enable_pacman_option "VerbosePkgLists"
  enable_pacman_option "DisableDownloadTimeout"
  enable_pacman_option "ParallelDownloads" "3"
  enable_pacman_option "Color"
  check_and_enable_ilovecandy
  setup_pacman_hooks
}

# ====== System Update ======
update_system() {
  echo -e "${YELLOW}Updating system...${NC}"
  pacman -Syyu --noconfirm || error_exit "system update failed"
}

# ====== Install Essential Packages ======
install_essential_packages() {
  echo -e "${YELLOW}Installing core packages...${NC}"
  ESSENTIAL_PKGS=(pacman-contrib base-devel sudo wget curl git reflector man)
  pacman -S --needed --noconfirm "${ESSENTIAL_PKGS[@]}" || error_exit "package installation failed"
}

# ====== Mirror Optimization ======
optimize_mirrors() {
  echo -e "${YELLOW}Optimizing mirrors...${NC}"
  #change to your country code
  reflector --latest 20 --download-timeout 10 --sort rate -p https --fastest 10 --save /etc/pacman.d/mirrorlist || error_exit "reflector failed"
}

# ====== PATH Setup ======
setup_path() {
  echo -e "${YELLOW}Setting PATH priority...${NC}"

  cat >/etc/profile.d/10-path-priority.sh <<'EOF'
#!/bin/sh

if [ "$(id -u)" -eq 0 ]; then
    export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:$PATH"
else
    export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/games:/usr/games:$PATH"
fi

# Deduplicate & clean empty entries
export PATH="$(printf "%s" "$PATH" | awk -v RS=: -v ORS=: '!a[$1]++ && length($1)>0' | sed 's/:$//')"
EOF

  chmod +x /etc/profile.d/10-path-priority.sh
  chmod 755 /usr/bin /usr/sbin

  echo -e "${GREEN}PATH and permissions configured.${NC}"
}

# ====== Root Password Setup ======
set_root_password() {
  echo -e "${YELLOW}Setting root password...${NC}"
  while true; do
    if passwd root; then
      echo -e "${GREEN}Root password set successfully${NC}"
      break
    else
      echo -e "${RED}Failed to set root password. Try again.${NC}"
    fi
  done
}
# ====== User Account Setup ======
create_user_account() {
  echo -e "${YELLOW}Creating user account...${NC}"
  while true; do
    read -rp "Enter new username: " USERNAME
    if ! [[ "$USERNAME" =~ ^[a-z][a-z0-9_-]{2,15}$ ]]; then
      echo -e "${RED}Invalid username format. Must start with a letter and be 3-16 chars.${NC}"
      continue
    fi
    if id "$USERNAME" &>/dev/null; then
      read -rp "User exists. Use existing? (y/N): " RESP
      if [[ "$RESP" =~ ^[Yy]$ ]]; then
        break
      else
        continue
      fi
    else
      break
    fi
  done

  if ! id "$USERNAME" &>/dev/null; then
    echo -e "${YELLOW}Creating user $USERNAME...${NC}"
    if useradd -m -G wheel -s /bin/bash "$USERNAME"; then
      echo -e "${YELLOW}Set password for $USERNAME:${NC}"
      while true; do
        if passwd "$USERNAME"; then
          echo -e "${GREEN}Password set for $USERNAME${NC}"
          break
        else
          echo -e "${RED}Failed to set password. Try again.${NC}"
        fi
      done
    else
      echo -e "${RED}useradd failed${NC}"
      exit 1
    fi
  fi
}
# ====== Sudo Access Setup ======
enable_sudo() {
  echo -e "${YELLOW}Enabling sudo for wheel group...${NC}"

  if grep -qE '^\s*%wheel\s+ALL=\(ALL:ALL\)\s+ALL' /etc/sudoers; then
    echo -e "${GREEN}Sudo already enabled for wheel group.${NC}"
  else
    cp /etc/sudoers /etc/sudoers.bak
    sed -i 's|^#\s*%wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|' /etc/sudoers
    if visudo -c; then
      echo -e "${GREEN}Sudo enabled for wheel group.${NC}"
    else
      echo -e "${RED}Syntax error in /etc/sudoers! Restoring backup.${NC}"
      cp /etc/sudoers.bak /etc/sudoers
      exit 1
    fi
  fi

  if usermod -aG wheel "$USERNAME"; then
    echo -e "${GREEN}Added $USERNAME to wheel group${NC}"
  else
    echo -e "${RED}Failed to add $USERNAME to wheel group${NC}"
  fi
}

# ====== Set WSL Default User ======
configure_wsl_defaults() {
  echo -e "${YELLOW}Configuring WSL defaults...${NC}"
  cat >/etc/wsl.conf <<EOF
[user]
default = $USERNAME

[interop]
enabled = true

[boot]
systemd=true
EOF
  echo -e "${GREEN}WSL user and systemd enabled${NC}"
}

# ====== Fix Home Permissions ======
fix_home_permissions() {
  chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"
}

# ====== Main Setup Function ======
setup_arch_wsl() {
  require_root
  echo -e "${BLUE}>>> Starting Arch WSL setup...${NC}"
  setup_keyring
  configure_locale
  optimize_pacman
  update_system
  install_essential_packages
  optimize_mirrors
  setup_path
  set_root_password
  create_user_account
  enable_sudo
  configure_wsl_defaults
  fix_home_permissions
  echo -e "${GREEN}✅ Setup complete!${NC}"
  echo -e "${YELLOW}>>> Restarting WSL...${NC}"
}

# Run the setup
setup_arch_wsl
