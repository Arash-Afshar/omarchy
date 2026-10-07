echo "Install the Dell XPS 13 Panther Lake speaker firmware"

if omarchy-hw-dell-xps13-dx13260-ptl; then
  firmware_pending="/run/omarchy/xps13-ptl-speaker-firmware"
  if omarchy-pkg-missing linux-firmware-cirrus-dx13260; then
    sudo install -Dm644 /dev/null "$firmware_pending"
  fi

  source "$OMARCHY_PATH/install/hardware/dell-xps13-ptl-speaker-firmware.sh"

  # The marker lasts until reboot so every user migrating beforehand is prompted.
  if [[ -e $firmware_pending ]]; then
    omarchy-state set reboot-required
  fi
fi
