#!/bin/bash

set_usb_lock() {
    state=$1
    for device in /sys/bus/usb/devices/usb*/authorized_default; do
        if [ -w "$device" ]; then
            echo "$state" > "$device"
        fi
    done
}

set_usb_lock 0

hyprlock

set_usb_lock 1

