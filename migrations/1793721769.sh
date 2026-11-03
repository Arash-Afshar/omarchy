echo "Generate the Oh My Pi theme, and activate it when Oh My Pi is the default agent"

theme_state="$HOME/.local/state/omarchy/current"

[[ -s $theme_state/theme.name ]] || exit 0

# A staged theme is only re-rendered when the theme changes, so a machine that
# keeps its theme would never get omp.json. A theme removed while current has
# nothing to re-stage from; leave it, the next theme switch renders omp.json.
if [[ ! -f $theme_state/theme/omp.json ]]; then
  theme_name=$(<"$theme_state/theme.name")
  if [[ -d $OMARCHY_PATH/themes/$theme_name || -d $HOME/.config/omarchy/themes/$theme_name ]]; then
    omarchy-theme-refresh || true
  fi
fi

# Choosing Oh My Pi as the default agent is what activates its theme, and for
# anyone already using it that choice is long past.
if [[ -f $theme_state/theme/omp.json && $(omarchy-default-agent 2>/dev/null) == "omp" ]]; then
  omarchy-theme-set-omp --activate || true
fi

exit 0
