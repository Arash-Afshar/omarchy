if omarchy-hw-dell-xps13-dx13260-ptl; then
  if omarchy-pkg-missing linux-firmware-cirrus-dx13260; then
    firmware_pending="/run/omarchy/xps13-ptl-speaker-firmware"
    sudo install -Dm644 /dev/null "$firmware_pending"
  fi
  omarchy-pkg-add linux-firmware-cirrus-dx13260
fi
