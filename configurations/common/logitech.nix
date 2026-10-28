# Lets Solaar (and the GNOME/GDM desktops on thinkpad and desktop) manage
# Logitech peripherals like the MX Master mouse and MX Keys keyboard: adds
# the udev rules needed to talk to their HID++ devices without root, plus
# Solaar itself and its tray applet. Bluetooth is enabled too since the
# MX Master/MX Keys connect either via a Unifying receiver or directly over
# Bluetooth, and pairing for the latter happens through normal Bluetooth
# tooling, not Solaar.
{
  hardware.bluetooth.enable = true;

  hardware.logitech.wireless.enable = true;
  programs.solaar.enable = true;
}
