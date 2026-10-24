#!/usr/bin/env bash
#
# git-status-all.command — macOS Finder Double-Click Launcher
#
# Double-clicking this file in macOS Finder launches Terminal.app,
# sets the working directory to this script's directory, and runs git-status-all.sh.
#

cd "$(dirname "$0")" || exit 1

if [[ -x "./git-status-all.sh" ]]; then
    exec ./git-status-all.sh "$@"
else
    exec bash ./git-status-all.sh "$@"
fi
