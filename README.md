# MERN VPS Auto Setup

This repository provides a **one-command setup script** for configuring an **Ubuntu 22.04 VPS** to host multiple **MERN stack** projects.

## 🚀 Features
- **Supports Custom or GitHub-based projects**
- **Asks for a domain name** and sets up the project accordingly
- **Creates a proper project structure (`server`, `client`)**
- **Detects & configures backend (`server.js`) and frontend (`React`) automatically**
- **Installs dependencies (`npm install`)**
- **Configures `.env` file dynamically**
- **Sets up MongoDB database & user (if needed)**
- **Runs backend using `PM2`**
- **Builds frontend and serves it statically**
- **Configures `Nginx` reverse proxy**
- **Supports `SSL` via Certbot (Let's Encrypt)**

---

## 🔧 **1️⃣ Pre-Configuration (First Time)**
Before installing a project, update your VPS:
```bash
sudo apt update && sudo apt upgrade -y && sudo apt install -y curl git ufw
```

---

## 🚀 **2️⃣ Quick Install (One Command)**
To deploy a project **(Custom or GitHub-based)** dynamically, run:
```bash
bash <(curl -sSL https://raw.githubusercontent.com/webservice-win/mern-vps/main/deploy_mern.sh)
```

Or manually:
```bash
git clone https://github.com/webservice-win/mern-vps.git
cd mern-vps
sudo chmod +x deploy_mern.sh
sudo ./deploy_mern.sh
```

---

## 📜 **3️⃣ How It Works**
1️⃣ **Choose Deployment Type**  
- Create a **New Custom Project** (Blank project with default structure)  
- Clone an **Existing GitHub Repository**  

2️⃣ **Enter the Domain Name**  
- The script configures everything for your **custom domain**.  

3️⃣ **Automatic Project Setup**  
- If GitHub, the script clones the repository.  
- If Custom, the script creates a folder with `server` and `client`.  

4️⃣ **Backend (`server/`)**  
- Detects `server.js`  
- Installs backend dependencies (`npm install`)  
- Creates `.env` if missing  
- Starts the backend using **PM2**  

5️⃣ **Frontend (`client/`)**  
- Detects React project  
- Installs frontend dependencies  
- Runs `npm run build`  
- Copies `build/` to `/var/www/html/projectname`  

6️⃣ **Server & SSL Setup**  
- Configures `Nginx` for reverse proxy  
- Enables **SSL** via Let's Encrypt  

---

## 🔧 **4️⃣ After Installation**
### ✅ **Manage Running Applications**
```bash
pm2 list              # View running apps
pm2 restart <app>     # Restart an app
pm2 logs <app>        # View logs
```

### ✅ **Restart Nginx**
```bash
sudo systemctl restart nginx
```

### ✅ **Enable SSL (Optional)**
If you skipped SSL during setup, enable it manually:
```bash
sudo certbot --nginx -d yourdomain.com
```

---

## 📌 **Notes**
- Ensure your **domain DNS is correctly set up** before enabling SSL.
- If a project already exists, the script will **pull the latest updates**.
- Fully supports **React, Node.js, MongoDB, and Express.js**.

📌 **Created by [Webservice.win](https://github.com/webservice-win)**
