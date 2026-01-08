#!/bin/bash

# --- 1. Официальные пакеты (Pacman) ---
NATIVE_PKGS=(
    # --- X11 и i3 ---
    "xorg-server"                 
    "xorg-xinit"                  
    "xorg-xrandr"                 
    "i3-wm"                       # Сам оконный менеджер 
    "i3lock"                      # Блокировщик экрана
    
    # --- Интерфейс и украшательства  ---
    "polybar"                     # Основной бар 
    "rofi"                        # Лаунчер 
    "picom"                       # Композитор 
    "feh"                         # Установка обоев 
    "nitrogen"                    # Еще одна утилита для обоев 
    "numlockx"                    # Включение NumLock при старте
    "lxsession"                   # Polkit агент (exec lxsession)

    # --- Системные утилиты ---
    "xss-lock"                    # Авто-лок при засыпании 
    "dex"                         # Автозапуск .desktop файлов 
    "xclip"                       # Буфер обмена для X11 
    "flameshot"                   # Скриншоты 
    "gnome-keyring"               # Пароли
    "zram-generator"

    # --- Софт (User Apps) ---
    "flatpak"
    "kitty"
    "thunar"                      
    "firefox"
    "telegram"
    "obs-studio"
    "mpd"
    "ncmpcpp"
    "mpv"
    "opentabletdriver"           

    # --- Инструменты (CLI) ---
    
    "ueberzugpp"                  # Картинки в терминале (для lf)
    "lf"                          
    "neovim"
    "zsh"
    "fzf"
    "ripgrep"
    "unzip"
    "7zip"
    "man-db"
    
    # --- Темизация ---
    "materia-gtk-theme"
    "papirus-icon-theme"

    # --- Виртуализация ---
    "qemu-full"
    "virt-manager"
    "podman"

    # --- NVIDIA ---
    "nvidia-open"
    "nvidia-settings"             
    "nvidia-utils"
    "libva-nvidia-driver"

    # --- Шрифты и темы ---
    "ttf-hack"                    # Указан в конфиге
    "otf-ipafont"                 # Японский шрифт (IPAPGothic)
    "noto-fonts-cjk"              # Иероглифы
    "ttf-jetbrains-mono-nerd"     # Nerd Font
    "ttf-font-awesome"            # Иконки
    "materia-gtk-theme"
    "papirus-icon-theme"
)

# --- 2. Пакеты AUR (Yay) ---
AUR_PKGS=(
    "qownnotes"
    "kopia-bin"
    "localsend"
    "goldendict-ng"
    "anki-bin"
    "coolercontrol-bin"
)

FLATPAK_PKGS=(
    "com.github.tchx84.Flatseal"
    "org.mozilla.firefox"
    "org.telegram.desktop"
    "ru.linux_gaming.PortProton"
)

# --- УСТАНОВКА ---

echo "--- Устанавливаем пакеты ---"
sudo pacman -S --needed "${NATIVE_PKGS[@]}"

echo "--- Устанавливаем пакеты AUR ---"
yay -S --needed "${AUR_PKGS[@]}"
echo "--- Готово! ---"

#echo "--- Устанавливаем пакеты Flatpak ---"
#yay -S --needed "${FLATPAK_PKGS[@]}"
