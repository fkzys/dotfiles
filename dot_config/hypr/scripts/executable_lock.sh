#!/bin/bash

set_usb_lock() {
    local state=$1
    for device in /sys/bus/usb/devices/usb*/authorized_default; do
        if [ -w "$device" ]; then
            echo "$state" > "$device"
        fi
    done
}

ssh-add -D
keys-vault close
set_usb_lock 0
hyprlock

set_usb_lock 1
keys-vault open
systemctl --user restart hyprsunset
