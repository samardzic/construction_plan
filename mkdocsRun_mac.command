#!/usr/bin/env bash


# ---------------------------------------------------------------------
# Description      : Bash script for mkdocs start
# ---------------------------------------------------------------------


# ******* MKdocs startup script ********

echo -e "\n######################  MKdocs Start  #####################\n"
cd /Users/nenads/Build/construction_plan
mkdocs serve --livereload -a 127.0.0.1:9006
