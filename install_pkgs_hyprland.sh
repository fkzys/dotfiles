#!/bin/bash

# --- 1. Официальные пакеты (Pacman) ---
NATIVE_PKGS=(
    # --- Графическое окружение (Hyprland) ---
    "hyprland"
    "xdg-desktop-portal-hyprland" # Нужен для OBS и шаринга экрана
    "xdg-desktop-portal-gtk"      # Для диалогов открытия файлов
    "waybar"                      # Бар
    "swaybg"                      # Обои
    "wofi"                        # Лаунчер (меню)
    "polkit-gnome"                # GUI для ввода пароля root
    "gnome-keyring"               # Хранение паролей
    "hypridle"                    # Демон простоя 
    "hyprlock"

    # --- Ввод и Язык (Fcitx5) ---
    "fcitx5-im"                   # Мета-пакет (все нужные модули)
    "fcitx5-kkc"                  # Японский ввод
    "fcitx5-material-color"       # Тема для fcitx

    # --- Софт ---
    "kitty"
    "thunar"                      
    "firefox"
    "telegram-desktop"
    "obs-studio"
    "mpd"                         
    "ncmpcpp"                     
    "mpv"                         
    "opentabletdriver"
    "nextcloud-client"

    # --- Инструменты (CLI & Utils) ---
    "grim"                        # Скриншоты (захват)
    "slurp"                       # Скриншоты (выделение области)
    "wl-clipboard"                # Буфер обмена
    "ueberzugpp"                  # Картинки в терминале (для lf)
    "flameshot"
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

# --- 2. Пакеты AUR (Yay/Paru) ---
AUR_PKGS=(
    "qownnotes"
    "kopia-bin"
    "localsend"
    "goldendict-ng"
    "anki-bin"
    "coolercontrol-bin"
)

# --- УСТАНОВКА ---

echo "--- Устанавливаем пакеты ---"
sudo pacman -S --needed "${NATIVE_PKGS[@]}"

echo "--- Устанавливаем пакеты AUR ---"
yay -S --needed "${AUR_PKGS[@]}"
echo "--- Готово! ---"
