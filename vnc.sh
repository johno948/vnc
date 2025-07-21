#!/bin/bash
set -e

echo "=============================="
echo "   🚀 JOHN VPS INSTALLER 🚀   "
echo "=============================="

# Ask for username, password, SSH port
read -p "Enter VPS username (non-root): " vps_user
read -sp "Enter password for $vps_user: " vps_pass
echo
read -p "Enter custom SSH port (e.g. 2222): " ssh_port

# Detect public IP
public_ip=$(curl -s https://ipinfo.io/ip || curl -s https://api.ipify.org)

# Create user if not exists
if id "$vps_user" &>/dev/null; then
    echo "✅ User $vps_user already exists."
else
    sudo adduser --gecos "" "$vps_user"
    echo "$vps_user:$vps_pass" | sudo chpasswd
    sudo usermod -aG sudo "$vps_user"
    echo "✅ User $vps_user created and added to sudo group."
fi

# Update system
echo "🔄 Updating system..."
sudo apt update && sudo apt upgrade -y

# Change SSH port
echo "🔧 Configuring SSH port to $ssh_port..."
sudo sed -i "s/^#\?Port .*/Port $ssh_port/" /etc/ssh/sshd_config
sudo systemctl restart ssh

# Setup UFW Firewall
echo "🧱 Configuring UFW firewall..."
sudo ufw allow "$ssh_port"/tcp
sudo ufw allow 80,443,5901,6080/tcp
sudo ufw --force enable

# Install XFCE & VNC
echo "🖥️ Installing XFCE Desktop and TightVNC..."
sudo apt install -y xfce4 xfce4-goodies tightvncserver

# Setup VNC for the user
echo "🛠️ Setting up VNC server..."
sudo -u "$vps_user" bash <<EOF
vncserver
vncserver -kill :1
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup <<EOL
#!/bin/bash
xrdb \$HOME/.Xresources
startxfce4 &
EOL
chmod +x ~/.vnc/xstartup
EOF

# Install noVNC
echo "🌐 Installing noVNC..."
sudo apt install -y git python3-websockify python3-numpy
cd /opt
sudo git clone https://github.com/novnc/noVNC
cd /opt/noVNC
sudo git clone https://github.com/novnc/websockify
sudo cp vnc.html index.html

# Systemd Services
echo "⚙️ Creating systemd services..."
sudo tee /etc/systemd/system/novnc.service > /dev/null <<EOL
[Unit]
Description=noVNC server
After=network.target

[Service]
Type=simple
User=$vps_user
ExecStart=/usr/bin/websockify --web=/opt/noVNC 6080 localhost:5901
Restart=always

[Install]
WantedBy=multi-user.target
EOL

sudo tee /etc/systemd/system/vncserver.service > /dev/null <<EOL
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=$vps_user
ExecStart=/usr/bin/vncserver :1
ExecStop=/usr/bin/vncserver -kill :1
Restart=always

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable vncserver novnc
sudo systemctl start vncserver novnc

# Optional Cloudflare Tunnel
read -p "Do you want to install Cloudflare Tunnel? (y/n): " cf_choice
if [[ "$cf_choice" =~ ^[Yy]$ ]]; then
    echo "🌩 Installing Cloudflare Tunnel..."
    curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
    sudo mv cloudflared /usr/local/bin/
    sudo chmod +x /usr/local/bin/cloudflared
    echo "✅ Cloudflare Tunnel installed. Use \`cloudflared tunnel --url http://localhost:6080\`"
fi

# Optional Ngrok
read -p "Do you want to install Ngrok? (y/n): " ngrok_choice
if [[ "$ngrok_choice" =~ ^[Yy]$ ]]; then
    echo "🌐 Installing Ngrok..."
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
    sudo apt update && sudo apt install ngrok -y
    echo "✅ Ngrok installed. Run: ngrok http 6080"
fi

# Banner
echo "🎨 Adding SSH banner..."
echo -e "\nBanner /etc/issue.net" | sudo tee -a /etc/ssh/sshd_config
echo -e "🚀 Welcome to JOHN VPS 🚀\nEnjoy your server at $public_ip" | sudo tee /etc/issue.net
sudo systemctl restart ssh

# Done
echo ""
echo "🎉 DONE!"
echo "===================================="
echo "🔑 SSH:   ssh -p $ssh_port $vps_user@$public_ip"
echo "🌐 VNC:   http://$public_ip:6080"
echo "📦 Tunnel: Run Ngrok or Cloudflare Tunnel if enabled"
echo "===================================="
