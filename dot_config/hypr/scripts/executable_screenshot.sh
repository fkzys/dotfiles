#!/bin/bash

# Запускаем slurp и сохраняем геометрию в переменную
GEOMETRY=$(slurp)

# Если геометрия пустая , выходим
if [ -z "$GEOMETRY" ]; then
    exit 1
fi

# Делаем скриншот и передаем в swappy
grim -g "$GEOMETRY" - | swappy -f -
