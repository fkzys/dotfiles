#!/bin/bash

# Функция для переключения состояния
set_usb_lock() {
    state=$1 # 0 = block, 1 = allow
    # Ищем файлы
    for device in /sys/bus/usb/devices/usb*/authorized_default; do
        # Проверяем, можем ли мы писать
        if [ -w "$device" ]; then
            echo "$state" > "$device"
        fi
    done
}

# 1. Блокируем новые (пишем 0)
set_usb_lock 0

# 2. Запускаем локер
hyprlock

# 3. Разрешаем новые (пишем 1)
set_usb_lock 1
