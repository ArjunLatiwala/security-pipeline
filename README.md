This **README.md** is designed to guide you (or any other developer) through setting up, deploying, and maintaining this self-healing security stack.

---

# 🛡️ Self-Healing Security Pipeline (GCP)

This project automates the deployment of **SonarQube**, **DefectDojo**, and **OWASP Dependency Check** on a Google Cloud Platform (GCP) VM. 

### Key Features:
*   **Self-Healing:** A Systemd timer checks the health of the tools every 5 minutes. If a service is stopped or deleted, it is automatically reinstalled/restarted.
*   **Idempotent:** If the tools are already running, the script skips installation in milliseconds.
*   **Optimized:** Automatically creates **4GB of Swap Memory** and configures kernel limits for SonarQube.
*   **Fast:** Uses Docker containers for near-instant deployment.

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
This creates:
*   `gcp_timer_key` (Private Key - **Secret**)
*   `gcp_timer_key.pub` (Public Key - **Lock**)

### Step 2: Configure GCP (The Lock)
1.  Go to **GCP Console** > **Compute Engine** > **VM Instances**.
2.  Click your VM name > **Edit**.
3.  Scroll to **SSH Keys** > **Add Item**.
4.  Paste the contents of `gcp_timer_key.pub`.
5.  **Note the username** at the end of the string (e.g., `creolemacmini02`). You will need this for the GitHub Action.

### Step 3: Configure GitHub (The Key)
1.  In your GitHub Repo, go to **Settings** > **Secrets and variables** > **Actions**.
2.  Add **New Repository Secret**:
    *   `GCP_SSH_PRIVATE_KEY`: Paste the content of `gcp_timer_key`.
    *   `GCP_VM_IP`: Your GCP VM External IP.
3.  Update `.github/workflows/deploy.yml` with your GCP username.

### Step 4: Deploy
Push the code to your `main` branch:
```bash
git add .
git commit -m "Deploy security stack"
git push origin main
```
The GitHub Action will trigger, log into your GCP VM, and run the installation.

---

## 🔄 How the Self-Healing Works
The `setup.sh` script installs a **Systemd Timer** on your server. 

*   Every **5 minutes**, the server runs `/usr/local/bin/health-check.sh`.
*   **Scenario:** If you accidentally run `docker stop sonarqube`, within 5 minutes, the timer will detect it and run `docker start`.
*   **Scenario:** If the server reboots, the timer starts automatically and brings up the entire stack.

---

## 🖥️ Accessing the Tools

Once the pipeline finishes, wait 2-3 minutes for the services to initialize, then access them via your browser:

*   **SonarQube:** `http://<YOUR_VM_IP>:9000` (Default: `admin/admin`)
*   **DefectDojo:** `http://<YOUR_VM_IP>:8080`
*   **Dependency Check:** Run `dependency-check --help` via SSH to verify CLI installation.

---

## 📜 Maintenance Commands

If you need to check the status of the automation directly on the GCP server:

*   **Check the Log:** 
    `journalctl -u security-stack.service`
*   **Check the Timer Status:** 
    `systemctl status security-stack.timer`
*   **Manually Trigger a Health Check:**
    `sudo /usr/local/bin/health-check.sh`
*   **Check Memory/Swap:**
    `free -m`

---

## ⚠️ Important Security Note
The default passwords for SonarQube and DefectDojo should be changed immediately upon first login. Ensure your GCP Firewall (VPC Network) allows incoming traffic on ports 
`9000` (Sonar) and `8080` (Dojo).
