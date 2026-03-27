---

# 🛡️ Self-Healing Security Pipeline (GCP)

This project automates the deployment of **SonarQube**, **DefectDojo**, and **OWASP Dependency Check** on a Google Cloud Platform (GCP) VM. It is designed to be **idempotent** (skips if already installed) and **self-healing** (recovers automatically if tools are deleted).

### ✨ Key Features:
*   **Full NVD Sync:** The pipeline doesn't just install the tool; it downloads the **entire NVD vulnerability database** on the first run.
*   **Latest Versions:** Always installs the latest active **SonarQube Community Edition** and **Dependency Check v12.0.1**.
*   **Self-Healing:** A Systemd timer checks the health of the tools every 5 minutes. If a service is stopped or deleted, it is automatically reinstalled/restarted.
*   **Interactive Logs:** GitHub Actions shows live progress (percentages and download status) during installation.
*   **Optimized:** Automatically creates **4GB of Swap Memory** and configures kernel limits for SonarQube performance.

---

## 📂 Project Structure

```text
security-pipeline/
├── .github/workflows/
│   └── deploy.yml          # GitHub Action (The Pipeline)
├── scripts/
│   └── health-check.sh     # The "Engine" (Logic for Install/Checks)
├── systemd/
│   ├── security-stack.service  # Systemd definition
│   └── security-stack.timer    # The 5-minute scheduler
├── setup.sh                # Initial entry point for the VM
└── README.md
```

---

## 🛠️ Prerequisites

1.  **GCP VM:** Recommended `e2-standard-2` (2 vCPU, 8GB RAM) or higher.
2.  **OS:** Ubuntu 22.04 LTS.
3.  **Local Machine:** Terminal access to generate SSH keys.

---

## 🚀 Setup Instructions

### Step 1: Generate SSH Keys
On your local machine, generate the keys that will allow GitHub to talk to GCP:
```bash
ssh-keygen -t rsa -f gcp_timer_key -N ""
```

### Step 2: Configure GCP (The Lock)
1.  Go to **GCP Console** > **Compute Engine** > **VM Instances**.
2.  Click your VM name > **Edit**.
3.  Scroll to **SSH Keys** > **Add Item**.
4.  Paste the contents of `gcp_timer_key.pub`.
5.  **Note the username** at the end of the string.

### Step 3: Configure GitHub (The Key)
1.  In your GitHub Repo, go to **Settings** > **Secrets and variables** > **Actions**.
2.  Add **New Repository Secret**:
    *   `GCP_SSH_PRIVATE_KEY`: Paste the content of `gcp_timer_key`.
    *   `GCP_VM_IP`: Your GCP VM External IP (e.g., `35.188.1.103`).

### Step 4: Deploy
Push the code to your `main` branch:
```bash
git add .
git commit -m "Deploy latest security stack"
git push origin main
```

---

## 🔄 How the Self-Healing Works
The `setup.sh` script installs a **Systemd Timer** on your server. 

*   Every **5 minutes**, the server runs `/usr/local/bin/health-check.sh`.
*   **Scenario:** If you accidentally run `docker rm -f sonarqube`, within 5 minutes, the timer will detect it and pull the latest active image to restart it.
*   **Scenario:** If the server reboots, the timer starts automatically and brings up the entire stack.

---

## 🖥️ Terminal Verification Commands
SSH into your server to check the status: `ssh -i gcp_timer_key your-username-on-gcp-server@<YOUR_VM_IP>`

| Goal | Command |
| :--- | :--- |
| **Check Active Tools** | `sudo docker ps --format "table {{.Names}}\t{{.Status}}"` |
| **Check NVD Version** | `dependency-check --version` |
| **Check Memory/Swap** | `free -h` |
| **Check Install Logs** | `journalctl -u security-stack.service -f` |
| **Check Timer Status** | `systemctl list-timers | grep security-stack` |

---

## 🌐 Accessing the Tools (Browser)

Wait 5 minutes after the pipeline finishes for the databases to initialize.

*   **SonarQube (Latest Community):** `http://<YOUR_VM_IP>:9000`  
    *(Default Login: admin / admin — you must change this on first login)*
*   **DefectDojo:** `http://<YOUR_VM_IP>:8080`  
    *(To find Admin Password, run: `sudo docker logs defectdojo-initializer-1 | grep "Admin password:"`)*
*   **Dependency Check:** Run `dependency-check --help` via SSH to verify CLI usage.

---

## 📜 Troubleshooting
If the sites are not loading, ensure the **GCP Firewall** is open. Run this in GCP Cloud Shell:
```bash
gcloud compute firewall-rules create allow-security-stack-final \
    --allow tcp:9000,tcp:8080 \
    --source-ranges 0.0.0.0/0 \
    --description="Open SonarQube and DefectDojo ports"
```

---

## 📜 Important Note on NVD Database
The first time this pipeline runs, it downloads about **800MB - 1GB** of vulnerability data from the NVD. 
*   **Duration:** 15–30 minutes.
*   **Subsequent Runs:** The 5-minute health check will only download small "delta" updates, taking only a few seconds.
*   **Recommendation:** If the download is extremely slow, consider getting an [NVD API Key](https://nvd.nist.gov/developers/request-an-api-key) and adding it to the command: `dependency-check --updateonly --nvdApiKey YOUR_KEY`.

---

## ⚠️ Important Security Note
The default passwords for SonarQube and DefectDojo should be changed immediately. This pipeline installs the tools with default configurations meant for setup; harden these settings before using them for production data.
