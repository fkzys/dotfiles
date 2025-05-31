#!/usr/bin/env bash

set -euo pipefail  # Включаем строгий режим: ошибки → остановка, неустановленные переменные → ошибка

# Выводит список аудиоустройств в формате для rofi/dmenu
get_audio_devices() {
    wpctl status | awk 'BEGIN {found=0} /Sources:/ {found=1} found==0 {print}' | grep -A10 "Sinks:" | grep "  [0-9]\+\. " | tr -d "│"
}

# Показывает меню выбора устройства (можно заменить rofi на dmenu/fzf)
show_device_menu() {
    rofi -dmenu -p "Select audio device"
}

# Извлекает ID устройства из строки (например, "42. Super Audio" → 42)
extract_device_id() {
    awk '{print $1}'
}

# Устанавливает устройство по умолчанию
set_default_device() {
    local device_id="$1"
    wpctl set-default "$device_id"
}

# Основная логика скрипта
main() {
    local selected_device

    echo "Получаем список устройств..." >&2
    selected_device=$(
        get_audio_devices | 
        show_device_menu | 
        extract_device_id
    )

    if [[ -z "$selected_device" ]]; then
        echo "Ошибка: устройство не выбрано!" >&2
        exit 1
    fi

    echo "Устанавливаем устройство $selected_device как default..." >&2
    set_default_device "$selected_device"

    echo "Готово! Устройство $selected_device теперь default." >&2
}

# Запускаем скрипт
main "$@"
