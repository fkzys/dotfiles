# --- ПРОСТОЙ ПРОФИЛЬ ДЛЯ ARCH LINUX ---

# 1. БАЗОВАЯ БЛОКИРОВКА СИСТЕМНЫХ ПАПОК
# Запрещаем запись в системные папки (они и так root, но на всякий случай)
read-only /

# Запрещаем доступ к /boot, /root и другим критичным местам
blacklist /boot
blacklist /root

# 2. ИЗОЛЯЦИЯ /HOME (ГЛАВНАЯ ЗАЩИТА)
# Firefox будет видеть только ~/.mozilla и ~/Downloads
# Остальные файлы в /home/user будут скрыты
mkdir ${HOME}/.mozilla
whitelist ${HOME}/.mozilla
whitelist ${HOME}/Downloads

# Разрешаем доступ к общим ресурсам (темы, шрифты, конфиги GTK)
# Без этого иконки не прогрузятся, так как whitelist скрывает всё остальное
noblacklist ${HOME}/.local/share/fonts
noblacklist ${HOME}/.icons
noblacklist ${HOME}/.config/gtk-3.0
noblacklist ${HOME}/.config/gtk-4.0
noblacklist ${HOME}/.config/dconf

# 3. СЕТЬ И ОБОРУДОВАНИЕ
# Оставляем стандартные ограничения
caps.drop all
netfilter
nodvd
nogroups

# 4. ЧТО МЫ НЕ ВКЛЮЧАЕМ (ЧТОБЫ НЕ ЛОМАТЬ ARCH)
# Мы НЕ включаем private-bin (пусть видит все бинарники)
# Мы НЕ включаем private-lib (пусть видит все либы)
# Мы НЕ включаем seccomp/nonewprivs (иначе сломается glycin/bwrap)
# Мы НЕ блокируем Python/Perl (нужны для xdg-open)

name firefox
