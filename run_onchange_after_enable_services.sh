#!/bin/bash
set -e

echo "--- User services ---"
systemctl --user enable hypridle hyprpaper hyprpolkitagent hyprsunset waybar mpd

echo "--- System services ---"
sudo systemctl enable firewalld
