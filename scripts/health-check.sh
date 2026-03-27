#!/bin/bash
set -e # Exit if any command fails

echo "===================================================="
echo "🚀 STARTING SECURITY STACK INSTALLATION/CHECK"
echo "===================================================="

# --- 1. SWAP MEMORY ---
echo "--- [STEP 1/5] VERIFYING SWAP MEMORY (4GB) ---"
if [ -z "$(swapon --show)" ]; then
    echo ">> Creating 4GB Swap..."
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
    echo ">> ✅ Swap created successfully."
else
    echo ">> ✅ Swap already present."
fi
free -h

# --- 2. DOCKER & COMPOSE ---
echo "--- [STEP 2/5] VERIFYING DOCKER & COMPOSE ---"
if ! command -v docker &> /dev/null; then
    echo ">> Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh
fi
# Ensure Docker Compose Plugin is installed (Needed for DefectDojo)
sudo apt-get update && sudo apt-get install -y docker-compose-plugin
echo ">> ✅ Docker version: $(docker --version)"

# --- 3. SONARQUBE ---
echo "--- [STEP 3/5] VERIFYING SONARQUBE ---"
sudo sysctl -w vm.max_map_count=262144
if [ -z "$(sudo docker ps -q --filter "name=sonarqube")" ]; then
    echo ">> Starting SonarQube Container..."
    sudo docker rm -f sonarqube > /dev/null 2>&1 || true
    sudo docker run -d --name sonarqube --restart always -p 9000:9000 sonarqube:lts-community
    echo ">> ✅ SonarQube started."
else
    echo ">> ✅ SonarQube is already running."
fi

# --- 4. DEFECTDOJO ---
echo "--- [STEP 4/5] VERIFYING DEFECTDOJO ---"
if [ ! -d "/opt/defectdojo" ]; then
    echo ">> Cloning DefectDojo..."
    sudo git clone https://github.com/DefectDojo/django-DefectDojo /opt/defectdojo
fi

if [ -z "$(sudo docker ps -q --filter "name=uwsgi")" ]; then
    echo ">> Starting DefectDojo (This pulls many images, please wait)..."
    cd /opt/defectdojo
    # We use 'docker compose' directly for better logs
    sudo docker compose --profile mysql-rabbit up -d --progress plain
    echo ">> ✅ DefectDojo containers initiated."
else
    echo ">> ✅ DefectDojo is already running."
fi

# --- 5. NVD DEPENDENCY CHECK ---
echo "--- [STEP 5/5] VERIFYING NVD DEPENDENCY CHECK ---"
if [ ! -f "/usr/local/bin/dependency-check" ]; then
    echo ">> Downloading Dependency Check Binary..."
    sudo apt-get install -y unzip openjdk-17-jre-headless wget
    wget https://github.com/jeremylong/DependencyCheck/releases/download/v9.0.9/dependency-check-9.0.9-release.zip -P /tmp
    sudo unzip -o /tmp/dependency-check-9.0.9-release.zip -d /opt/
    sudo ln -sf /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check
    echo ">> ✅ Dependency Check installed."
else
    echo ">> ✅ Dependency Check already present."
fi
dependency-check --version

echo "===================================================="
echo "🎉 ALL SYSTEMS VERIFIED AND RUNNING"
echo "===================================================="