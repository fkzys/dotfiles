#!/bin/bash
set -e

echo "--- User services ---"
systemctl --user enable hypridle hyprpaper hyprpolkitagent hyprsunset waybar mpd
systemctl --user enable com.nextcloud.desktopclient.nextcloud

echo "--- System services ---"
sudo systemctl enable firewalld
