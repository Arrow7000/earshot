#!/bin/zsh
# Stop Inner Ear and remove it.
LABEL=arrow7000.innerear
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Library/Application Support/Inner Ear"
rm -f "$HOME/Library/Logs/InnerEar.log"
tccutil reset AudioCapture $LABEL >/dev/null 2>&1 || true
echo "Inner Ear uninstalled."
