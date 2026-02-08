#!/bin/bash
for f in $(fd *.age); do
    chezmoi decrypt "$f" | chezmoi encrypt > "${f}.new"
    mv "${f}.new" "$f"
done
