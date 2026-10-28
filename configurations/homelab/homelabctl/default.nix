{ writers }:

writers.writePython3Bin "homelabctl" {
  flakeIgnore = [
    "E501"
    "W503"
  ];
} (builtins.readFile ./homelabctl.py)
