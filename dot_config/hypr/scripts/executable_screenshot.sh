#!/bin/bash
# Take a screenshot of a selected region and open it in swappy for editing.
# Dependencies: slurp, grim, swappy

# Run slurp to select a region and save the geometry
GEOMETRY=$(slurp)

# Exit if no region was selected
if [ -z "$GEOMETRY" ]; then
    exit 1
fi

# Capture the screenshot and pipe it to swappy
grim -g "$GEOMETRY" - | swappy -f -
