source /etc/X11/xinit/xinitrc.d/50-systemd-user.sh
eval $(gnome-keyring-daemon --start)
#export SSH_AUTH_SOCK
[[ -f ~/.Xresources ]] && xrdb -merge -I$HOME ~/.Xresources
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

export QT_QPA_PLATFORMTHEME=qt6ct

export LIBVA_DRIVER_NAME=nvidia
export VDPAU_DRIVER=nvidia

#https://tatsumoto-ren.github.io/blog/setting-up-anki.html
export PATH="${PATH}:${HOME}/.local/bin"

nextcloud &
flameshot &
mpd &
fcitx -dr &
exec i3
