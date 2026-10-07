#!/bin/zsh
# Stop Earshot and remove it.
LABEL=arrow7000.earshot
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Library/Application Support/Earshot"
rm -f "$HOME/Library/Logs/Earshot.log"
tccutil reset AudioCapture $LABEL >/dev/null 2>&1 || true
echo "Earshot uninstalled."
