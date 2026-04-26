#!/bin/bash
# Manually remove the sudoers entry installed by DontSleep.
# Usage: ./scripts/uninstall_sudoers.sh
set -e
sudo rm -f /etc/sudoers.d/dontsleep
echo "Removed /etc/sudoers.d/dontsleep"
