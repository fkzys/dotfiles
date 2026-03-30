#!/bin/bash
set -e

echo "--- User services ---"
systemctl --user enable hypridle hyprpaper hyprpolkitagent hyprsunset waybar mpd ssh-agent keys-vault ssh-add

# System services live here (not in system-config aka root-chezmoi) to keep all service
# enablement in one place and avoid requiring a separate apply step.
echo "--- System services ---"
sudo systemctl enable firewalld systemd-oomd
