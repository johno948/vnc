#!/bin/bash

# Ask for VPS username, password, IP, and port
read -p "Enter VPS username: " VPS_USER
read -s -p "Enter VPS password: " VPS_PASS
echo
read -p "Enter VPS IP (e.g., 192.168.1.100): " VPS_IP
read -p "Enter SSH Port (default 22): " VPS_PORT
VPS_PORT=${VPS_PORT:-22}

# Ask for a custom VPS code (used in /etc/hosts)
read -p "Enter a custom VPS code: " VPS_CODE

# Set up /etc/hosts with custom VPS code (non-root method using sudo if available)
echo -e "127.0.0.1\tlocalhost ${VPS_CODE}\n::1\tlocalhost ip6-localhost ip6-loopback\nfe00::\tip6-localnet\nff00::\tip6-mcastprefix\nff02::1\tip6-allnodes\nff02::2\tip6-allrouters" | sudo tee /etc/hosts > /dev/null

# Install essential packages
sudo apt update && sudo apt install -y \
    htop neofetch curl gnupg nano ufw

# System branding and status
clear
neofetch

echo "✨ Welcome to JOHN VPS on $HOSTNAME"
echo "🔐 SSH Login: ssh -p ${VPS_PORT} ${VPS_USER}@${VPS_IP}"
echo "💡 VPS Code: ${VPS_CODE}"

# Function: Install XFCE + VNC + noVNC
echo "📦 Installing XFCE + VNC + noVNC..."
sudo apt install -y xfce4 xfce4-goodies tightvncserver websockify novnc

# Setup VNC server
mkdir -p ~/.vnc
echo "${VPS_PASS}" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

cat > ~/.vnc/xstartup <<EOF
#!/bin/sh
xrdb $HOME/.Xresources
startxfce4 &
EOF
chmod +x ~/.vnc/xstartup

# Start VNC server
vncserver :1

# Start noVNC web access (on port 6080)
websockify --web=/usr/share/novnc/ 6080 localhost:5901 &
echo "🌐 Access GUI via: http://${VPS_IP}:6080"

# Ask user if they want to install Cloudflare Tunnel
echo -n "Want to install Cloudflare Tunnel? (y/n): "
read cf
if [ "$cf" == "y" ]; then
  curl -fsSL https://developers.cloudflare.com/cloudflare-one/static/downloads/cloudflared-linux-amd64.deb -o cloudflared.deb
  sudo dpkg -i cloudflared.deb
  cloudflared tunnel login
  echo "✅ Cloudflare Tunnel setup complete."
fi

# Ask user if they want to install Ngrok
echo -n "Want to install Ngrok? (y/n): "
read ng
if [ "$ng" == "y" ]; then
  curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
  sudo apt update && sudo apt install -y ngrok
  echo "✅ Ngrok installed."
fi

# Optional firewall configuration
sudo ufw allow ${VPS_PORT}/tcp
sudo ufw allow 5901/tcp
sudo ufw allow 6080/tcp
sudo ufw enable

# 24/7 process keep-alive script
cat > ~/keepalive.sh <<EOF
#!/bin/bash
while true; do
  date
  echo "🌐 VPS Alive..."
  sleep 3600
done
EOF
chmod +x ~/keepalive.sh
nohup ~/keepalive.sh >/dev/null 2>&1 &

# Final message
echo "✅ VPS setup is complete. Your VPS will remain active 24/7."
echo "🟢 SSH Access: ssh -p ${VPS_PORT} ${VPS_USER}@${VPS_IP}"
echo "🖥️ VNC Access: http://${VPS_IP}:6080"
