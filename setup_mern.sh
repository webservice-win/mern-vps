#!/bin/bash

set -e  # Exit on error

# Function to install missing dependencies
install_dependency() {
    if ! dpkg -s "$1" &>/dev/null; then
        echo "Installing $1..."
        sudo apt install -y "$1"
    else
        echo "$1 is already installed. Skipping..."
    fi
}

# Update & install required packages
echo "Updating system and installing required packages..."
sudo apt update && sudo apt upgrade -y
install_dependency curl
install_dependency git
install_dependency ufw
install_dependency nginx
install_dependency python3-certbot-nginx

# Configure firewall
echo "Configuring firewall..."
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable

# Install Node.js & PM2
if ! command -v node &>/dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
fi

if ! command -v pm2 &>/dev/null; then
    echo "Installing PM2..."
    npm install -g pm2
    pm2 startup systemd
fi

# Install MongoDB
if ! command -v mongod &>/dev/null; then
    echo "Installing MongoDB..."
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/mongodb-server-keyring.gpg] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    sudo apt update
    sudo apt install -y mongodb-org
    sudo systemctl start mongod
    sudo systemctl enable mongod
fi

# Ask for the project domain
read -p "Enter the domain name (e.g., myapp.example.com): " domain
read -p "Enter the application port (e.g., 3001): " app_port
read -p "Does this project require MongoDB? (y/n): " mongo_required

# Set project name from domain (remove dots)
project_name=$(echo "$domain" | tr '.' '-')
project_dir="/var/www/$project_name"

# Ask user for deployment type
echo "Choose Deployment Type:"
echo "1) Custom Project (New Project)"
echo "2) GitHub Project (Clone & Deploy)"
read -p "Enter your choice (1 or 2): " deploy_type

# If the user chooses a GitHub project
if [[ "$deploy_type" == "2" ]]; then
    read -p "Enter the Git repository URL: " repo_url

    # Clone or update the project
    if [ -d "$project_dir" ]; then
        echo "Project folder already exists. Pulling latest changes..."
        cd "$project_dir"
        git pull origin main
    else
        echo "Cloning repository into $project_dir..."
        sudo git clone "$repo_url" "$project_dir"
    fi
fi

# If the user chooses a Custom Project
if [[ "$deploy_type" == "1" ]]; then
    echo "Creating a new custom project at $project_dir..."
    sudo mkdir -p "$project_dir"
    cd "$project_dir"

    # Create default structure
    mkdir server client
    touch server/server.js client/index.html
    echo "console.log('Server running...');" > server/server.js
    echo "<h1>Welcome to $domain</h1>" > client/index.html
fi

# Detect backend and frontend folders
if [ -d "$project_dir/server" ]; then
    backend_dir="$project_dir/server"
else
    backend_dir="$project_dir"
fi

if [ -d "$project_dir/client" ]; then
    frontend_dir="$project_dir/client"
else
    frontend_dir=""
fi

# Setup .env file if missing
if [ ! -f "$backend_dir/.env" ]; then
    echo "Creating default .env file..."
    cat <<EOT > "$backend_dir/.env"
PORT=$app_port
MONGO_URI=mongodb://localhost:27017/$project_name
JWT_SECRET=your_secret_key
EOT
fi

# Setup MongoDB database and user if required
if [[ "$mongo_required" == "y" ]]; then
    echo "Setting up MongoDB..."
    mongo <<EOF
use $project_name
db.createUser({ user: "admin", pwd: "password", roles: [{ role: "readWrite", db: "$project_name" }] })
EOF
fi

# Install backend dependencies
if [ -f "$backend_dir/package.json" ]; then
    echo "Installing backend dependencies..."
    cd "$backend_dir"
    npm install
fi

# Start backend with PM2
echo "Starting backend with PM2..."
pm2 delete "$project_name" 2>/dev/null || true
pm2 start server.js --name "$project_name" --watch -- --port=$app_port
pm2 save

# Setup frontend if exists
if [[ ! -z "$frontend_dir" ]]; then
    echo "Frontend detected. Installing dependencies and building..."
    cd "$frontend_dir"
    npm install
    npm run build
    sudo mkdir -p /var/www/html/$project_name
    sudo cp -r build/* /var/www/html/$project_name
fi

# Configure Nginx
echo "Configuring Nginx reverse proxy for $domain..."
sudo tee /etc/nginx/sites-available/$project_name > /dev/null <<EOF
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://localhost:$app_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location /static {
        root /var/www/html/$project_name;
    }
}
EOF

# Enable Nginx configuration
sudo ln -sf /etc/nginx/sites-available/$project_name /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
echo "Nginx configuration for $domain is complete."

# SSL Setup
read -p "Do you want to enable SSL for $domain? (y/n): " enable_ssl
if [[ "$enable_ssl" == "y" ]]; then
    sudo certbot --nginx -d "$domain"
fi

echo "Deployment complete! Access your project at http://$domain"
