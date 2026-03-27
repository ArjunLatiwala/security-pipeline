#!/bin/bash

# --- Configuration ---
DOJO_DIR="/opt/defectdojo"
DC_DIR="/opt/dependency-check"
SWAP_FILE="/swapfile"

echo "--- Health Check Started: $(date) ---"

# 1. SWAP CHECK (Self-healing: Creates 4GB Swap if not present)
if [ -z "$(swapon --show)" ]; then
    echo "[!] No Swap detected. Creating 4GB Swap file..."
    
    # Create a 4GB file
    sudo fallocate -l 4G $SWAP_FILE
    
    # Secure the file (only root can read/write)
    sudo chmod 600 $SWAP_FILE
    
    # Set up the swap area
    sudo mkswap $SWAP_FILE
    
    # Enable the swap
    sudo swapon $SWAP_FILE
    
    # Make swap permanent (Add to fstab if not already there)
    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab
    fi
    echo "[✓] 4GB Swap created and enabled."
else
    echo "[✓] Swap memory is already present."
fi

# 2. DOCKER CHECK (Fastest Install)
if ! command -v docker &> /dev/null; then
    echo "[!] Docker missing. Installing..."
    curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
fi

# 3. SONARQUBE CHECK (Docker)
# SonarQube needs this kernel parameter or it will crash on startup
if [ "$(sysctl -n vm.max_map_count)" -lt "262144" ]; then
    echo "[!] Setting vm.max_map_count for SonarQube..."
    sudo sysctl -w vm.max_map_count=262144
fi

if [ ! "$(docker ps -q -f name=sonarqube)" ]; then
    echo "[!] SonarQube container not found or stopped. Starting..."
    # If a container exists but is stopped, remove it first to avoid name conflicts
    docker rm -f sonarqube > /dev/null 2>&1
    docker run -d --name sonarqube --restart always -p 9000:9000 sonarqube:lts-community
else
    echo "[✓] SonarQube is running."
fi

# 4. DEFECTDOJO CHECK (Docker Compose)
if [ ! -d "$DOJO_DIR" ]; then
    echo "[!] DefectDojo folder missing. Cloning..."
    sudo git clone https://github.com/DefectDojo/django-DefectDojo "$DOJO_DIR"
fi

# Check if the main uwsgi container is running
if [ ! "$(docker ps -q -f name=uwsgi)" ]; then
    echo "[!] DefectDojo containers not found. Starting..."
    cd "$DOJO_DIR"
    # Starting using the provided compose profile
    sudo ./dc-up.sh mysql-rabbit
else
    echo "[✓] DefectDojo is running."
fi

# 5. DEPENDENCY CHECK (Binary)
if [ ! -f "/usr/local/bin/dependency-check" ]; then
    echo "[!] Dependency Check missing. Installing..."
    sudo apt-get update && sudo apt-get install -y unzip openjdk-17-jre-headless wget
    wget https://github.com/jeremylong/DependencyCheck/releases/download/v9.0.9/dependency-check-9.0.9-release.zip -P /tmp
    sudo unzip /tmp/dependency-check-9.0.9-release.zip -d /opt/
    sudo ln -s /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check
    sudo rm /tmp/dependency-check-9.0.9-release.zip
else
    echo "[✓] Dependency Check is installed."
fi

echo "--- Health Check Completed: $(date) ---"
