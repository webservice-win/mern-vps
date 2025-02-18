#!/bin/bash

set -e  # Exit on error

# Ask for project details
read -p "Enter the domain name (e.g., myapp.example.com): " domain
read -p "Enter the application port (e.g., 3001): " app_port
read -p "Does this project require MongoDB? (y/n): " mongo_required

# Set project name from domain
project_name=$(echo "$domain" | tr '.' '-')
project_dir="/var/www/$project_name"

# Create project directories
echo "Creating MERN project at $project_dir..."
sudo mkdir -p "$project_dir/server" "$project_dir/client/src" "$project_dir/client/public"

# Backend setup (Express.js)
echo "Setting up backend..."
cat <<EOT > "$project_dir/server/package.json"
{
  "name": "server",
  "version": "1.0.0",
  "description": "MERN backend",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.17.1",
    "mongoose": "^6.5.0",
    "dotenv": "^16.0.1",
    "cors": "^2.8.5",
    "body-parser": "^1.19.0"
  }
}
EOT

cat <<EOT > "$project_dir/server/server.js"
require("dotenv").config();
const express = require("express");
const cors = require("cors");
const mongoose = require("mongoose");

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || $app_port;
const MONGO_URI = process.env.MONGO_URI || "mongodb://localhost:27017/$project_name";

mongoose.connect(MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
    .then(() => console.log("MongoDB Connected"))
    .catch(err => console.error(err));

app.get("/", (req, res) => {
    res.send("Hello, MERN Stack!");
});

app.listen(PORT, () => console.log(\`Server running on port \${PORT}\`));
EOT

# Create .env file
echo "Creating environment file..."
cat <<EOT > "$project_dir/server/.env"
PORT=$app_port
MONGO_URI=mongodb://localhost:27017/$project_name
EOT

# Frontend setup (React.js)
echo "Setting up frontend..."
cat <<EOT > "$project_dir/client/package.json"
{
  "name": "client",
  "version": "1.0.0",
  "description": "MERN frontend",
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test --env=jsdom",
    "eject": "react-scripts eject"
  },
  "dependencies": {
    "axios": "^0.27.2",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.3.0",
    "react-scripts": "5.0.1"
  }
}
EOT

cat <<EOT > "$project_dir/client/src/App.js"
import React, { useEffect, useState } from "react";
import axios from "axios";

function App() {
  const [message, setMessage] = useState("");

  useEffect(() => {
    axios.get("http://localhost:$app_port")
      .then(response => setMessage(response.data))
      .catch(error => console.error(error));
  }, []);

  return (
    <div>
      <h1>MERN Example Project</h1>
      <p>Server says: {message}</p>
    </div>
  );
}

export default App;
EOT

cat <<EOT > "$project_dir/client/public/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MERN Example</title>
</head>
<body>
    <div id="root"></div>
</body>
</html>
EOT

# Install dependencies
echo "Installing backend dependencies..."
cd "$project_dir/server"
npm install

echo "Installing frontend dependencies..."
cd "$project_dir/client"
npm install
npm run build

# MongoDB Setup (If required)
if [[ "$mongo_required" == "y" ]]; then
    echo "Setting up MongoDB database..."
    mongosh --eval "
    use $project_name;
    db.createUser({ user: 'admin', pwd: 'password', roles: [{ role: 'readWrite', db: '$project_name' }] });
    "
fi

# Start Backend using PM2
echo "Starting backend with PM2..."
pm2 delete "$project_name" 2>/dev/null || true
pm2 start "$project_dir/server/server.js" --name "$project_name" --watch -- --port=$app_port
pm2 save

# Configure Nginx
echo "Configuring Nginx..."
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

# Enable SSL
read -p "Do you want to enable SSL for $domain? (y/n): " enable_ssl
if [[ "$enable_ssl" == "y" ]]; then
    sudo certbot --nginx -d "$domain"
fi

echo "✅ Deployment complete! Access your project at: http://$domain"
