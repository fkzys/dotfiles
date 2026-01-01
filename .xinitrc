source /etc/X11/xinit/xinitrc.d/50-systemd-user.sh
eval $(gnome-keyring-daemon --start)
export SSH_AUTH_SOCK
export GPG_AGENT_INFO
export GNOME_KEYRING_CONTROL
export GNOME_KEYRING_PID
[[ -f ~/.Xresources ]] && xrdb -merge -I$HOME ~/.Xresources
export GTK_IM_MODULE=fcitx5
export QT_IM_MODULE=fcitx5
export XMODIFIERS=@im=fcitx5

export QT_QPA_PLATFORMTHEME=qt6ct

export LIBVA_DRIVER_NAME=nvidia
export VDPAU_DRIVER=nvidia

#https://tatsumoto-ren.github.io/blog/setting-up-anki.html
export PATH="${PATH}:${HOME}/.local/bin"

nextcloud &
flameshot &
mpd &
fcitx5 -dr &
exec i3
