#!/bin/bash
wpctl set-default "$(wpctl status | grep -A10 "Sinks:" | grep "  [0-9]\+\. " | tr -d "│" | rofi -dmenu -p "Select audio device" | awk '{print $1}')"
