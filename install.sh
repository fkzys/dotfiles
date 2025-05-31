#!/bin/bash

#you should set here your firefox profile name. you can check existings profiles via firefox -no-remote -P or ls $HOME/.mozilla/firefox | grep -v -e Crash -e Pending -e installs -e profiles
export firefox_profile=""

#dir
mkdir -p $HOME/.local/bin
mkdir -p $HOME/.config/containers
mkdir -p $HOME/.config/goldendict
mkdir -p $HOME/.config/mpd
mkdir -p $HOME/.config/mpv
mkdir -p $HOME/.config/ncmpcpp

#bin
ln -s $HOME/dotfiles/.local/bin/anki $HOME/.local/bin
ln -s $HOME/dotfiles/.local/bin/cabl $HOME/.local/bin
ln -s $HOME/dotfiles/.local/bin/dmenu $HOME/.local/bin
ln -s $HOME/dotfiles/.local/bin/lf $HOME/.local/bin
ln -s $HOME/dotfiles/.local/bin/lf/audio-device-switcher.sh $HOME/.local/bin

#config
ln -s $HOME/dotfiles/.config/containers/storage.conf $HOME/.config/containers/storage.conf
ln -s $HOME/dotfiles/.config/firefox/user-overrides.js $HOME/.mozilla/firefox/$firefox_profile
ln -s $HOME/dotfiles/.config/goldendict/config $HOME/.config/goldendict/config
ln -s $HOME/dotfiles/.config/i3 $HOME/.config
ln -s $HOME/dotfiles/.config/kitty $HOME/.config
ln -s $HOME/dotfiles/.config/lf $HOME/.config
ln -s $HOME/dotfiles/.config/mpd/mpd.conf $HOME/.config/mpd/mpd.conf
ln -s $HOME/dotfiles/.config/mpv/{input.conf,mpv.conf,script-opts} $HOME/.config/mpv
ln -s $HOME/dotfiles/.config/ncmpcpp/{bindings,config} $HOME/.config/ncmpcpp
ln -s $HOME/dotfiles/.config/nvim $HOME/.config
ln -s $HOME/dotfiles/.config/picom.conf $HOME/.config
ln -s $HOME/dotfiles/.config/polybar $HOME/.config
ln -s $HOME/dotfiles/.config/rofi $HOME/.config
