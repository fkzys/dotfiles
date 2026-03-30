#!/bin/bash
set -e

echo "--- User services ---"
systemctl --user enable hypridle hyprpaper hyprpolkitagent hyprsunset waybar mpd ssh-agent keys-vault ssh-add

echo "--- System services ---"
sudo systemctl enable firewalld systemd-oomd
