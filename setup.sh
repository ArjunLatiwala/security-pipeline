#!/bin/bash

# 1. Move health check script to bin
sudo cp scripts/health-check.sh /usr/local/bin/health-check.sh
sudo chmod +x /usr/local/bin/health-check.sh

# 2. Copy systemd files
sudo cp systemd/security-stack.service /etc/systemd/system/
sudo cp systemd/security-stack.timer /etc/systemd/system/

# 3. Reload and Start
sudo systemctl daemon-reload
sudo systemctl enable --now security-stack.timer

echo "Self-healing pipeline is now active."
