#!/bin/bash
set -e

echo "===================================================="
echo "🚀 STARTING LATEST SECURITY STACK INSTALLATION"
echo "===================================================="

# --- 1. SWAP MEMORY ---
echo "--- [STEP 1/5] VERIFYING 4GB SWAP ---"
if [ -z "$(swapon --show)" ]; then
    sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile
    sudo mkswap /swapfile && sudo swapon /swapfile
    echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
    echo ">> ✅ Swap created."
else
    echo ">> ✅ Swap already present."
fi

# --- 2. DOCKER ---
echo "--- [STEP 2/5] VERIFYING DOCKER & COMPOSE ---"
sudo apt-get update && sudo apt-get install -y docker-compose-plugin git
echo ">> ✅ Docker: $(docker --version)"

# --- 3. SONARQUBE (LATEST COMMUNITY) ---
echo "--- [STEP 3/5] VERIFYING SONARQUBE (LATEST) ---"
sudo sysctl -w vm.max_map_count=262144
if [ -z "$(sudo docker ps -q --filter "name=sonarqube")" ]; then
    echo ">> Starting SonarQube Community Edition..."
    sudo docker rm -f sonarqube > /dev/null 2>&1 || true
    # Using :community ensures you get the latest active stable version
    sudo docker run -d --name sonarqube --restart always -p 9000:9000 sonarqube:community
    echo ">> ✅ SonarQube started."
else
    echo ">> ✅ SonarQube is running."
fi

# --- 4. DEFECTDOJO (LATEST FROM REPO) ---
echo "--- [STEP 4/5] VERIFYING DEFECTDOJO ---"
if [ ! -d "/opt/defectdojo" ]; then
    sudo git clone --depth 1 https://github.com/DefectDojo/django-DefectDojo /opt/defectdojo
fi

if [ -z "$(sudo docker ps -q --filter "name=uwsgi")" ]; then
    echo ">> Starting DefectDojo..."
    cd /opt/defectdojo
    sudo docker compose --profile mysql-rabbit up -d
    echo ">> ✅ DefectDojo started."
else
    echo ">> ✅ DefectDojo is running."
fi

# --- [STEP 5/5] VERIFYING NVD DEPENDENCY CHECK (12.0.1) ---
echo "--- [STEP 5/5] VERIFYING DEPENDENCY CHECK & NVD DATABASE ---"

# 1. Upgrade Engine if version is old
if [[ -f "/usr/local/bin/dependency-check" ]] && [[ ! $(dependency-check --version) == *"12.0.1"* ]]; then
    echo ">> Old version detected. Removing to upgrade..."
    sudo rm -rf /opt/dependency-check /usr/local/bin/dependency-check
fi

# 2. Install Engine (if missing)
if [ ! -f "/usr/local/bin/dependency-check" ]; then
    echo ">> Downloading Dependency Check Engine 12.0.1..."
    sudo apt-get install -y unzip openjdk-17-jre-headless wget
    wget https://github.com/jeremylong/DependencyCheck/releases/download/v12.0.1/dependency-check-12.0.1-release.zip -P /tmp
    sudo unzip -o /tmp/dependency-check-12.0.1-release.zip -d /opt/
    sudo ln -sf /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check
    echo ">> ✅ Engine installed."
fi

# 3. INITIALIZE/UPDATE WHOLE NVD DATABASE
# We check if the data directory is empty. If it is, we do a full sync.
DATA_DIR="/opt/dependency-check/data"
if [ ! -d "$DATA_DIR" ] || [ -z "$(ls -A $DATA_DIR)" ]; then
    echo ">> 📥 NVD Database not found. Downloading the WHOLE database now..."
    echo ">> This step can take 20-30 minutes. Please do not cancel the pipeline."
    dependency-check --updateonly
    echo ">> ✅ NVD Database fully synchronized."
else
    echo ">> ✅ NVD Database present. (Robot will sync small daily updates in background)."
    # Optional: run a quick update check
    dependency-check --updateonly
fi

dependency-check --version

echo "===================================================="
echo "🎉 ALL SYSTEMS UP TO DATE"
echo "===================================================="