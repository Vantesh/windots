# load optionrc if it exists
[[ -f "${ZDOTDIR}/optionrc" ]] && source "${ZDOTDIR}/optionrc"

# load plugins if they exist
if [[ -d "${ZDOTDIR}/plugins" ]]; then
  for plugin in "${ZDOTDIR}"/plugins/*; do
    if [[ -d "$plugin" ]]; then
      plugin_name=$(basename "$plugin")
      if [[ -f "${plugin}/${plugin_name}.zsh" ]]; then
        source "${plugin}/${plugin_name}.zsh"
      fi
    fi
  done
fi

# exec ohmyposh
if command -v oh-my-posh &>/dev/null; then
  eval "$(oh-my-posh init zsh --config "${ZDOTDIR}/ohmyposh/ohmyposh.toml")"
fi
