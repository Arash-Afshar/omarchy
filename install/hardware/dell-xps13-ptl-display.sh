if omarchy-hw-dell-xps13-dx13260-ptl; then
  display_conf="/etc/limine-entry-tool.d/dell-xps13-ptl-display.conf"
  display_cmdline='KERNEL_CMDLINE[default]+=" xe.enable_psr2_sel_fetch=0 xe.enable_panel_replay=0"'

  if [[ ! -f $display_conf ]] || ! grep -Fxq "$display_cmdline" "$display_conf"; then
    sudo mkdir -p /etc/limine-entry-tool.d
    printf '%s\n' '# Dell XPS 13 Panther Lake display workaround' "$display_cmdline" |
      sudo tee "$display_conf" >/dev/null
  fi
fi
