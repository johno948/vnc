#!/bin/bash

# ==============================
#  VPS Setup Script by John Kylle
#  Includes XFCE, VNC, noVNC
#  With options for Playit, Cloudflare Tunnel, or Ngrok
#  Includes login monitoring and 24/7 keepalive
# ==============================

# Prompt VPS code and show SSH command
read -p "Enter your VPS code: " vpscode
clear
echo "✅ VPS Code set to: $vpscode"
echo "🛜 Use this SSH command to connect later:"
echo "ssh -p 22673 root@147.185.221.30"
echo "(Enter your VPS password when prompted)"

# Add VPS code to /etc/hosts
sudo tee /etc/hosts > /dev/null <<EOF
127.0.0.1       localhost $vpscode
::1             localhost ip6-localhost ip6-loopback
fe00::          ip6-localnet
ff00::          ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

# Update system and install essentials
sudo apt update && sudo apt install -y \
  htop neofetch curl wget nano ufw \
  xfce4 xfce4-goodies tightvncserver apache2 \
  python3 python3-pip git unzip net-tools

# Set SSH login banner
sudo tee /etc/update-motd.d/99-johnvps > /dev/null <<EOF
#!/bin/bash
echo "\e[1;32m=============================="
echo "       🖥️  JOHN VPS"
echo " Welcome to your 24/7 VPS!"
echo "==============================\e[0m"
neofetch
EOF
sudo chmod +x /etc/update-motd.d/99-johnvps

# Set up VNC
vncserver
vncserver -kill :1
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup <<EOF
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF
chmod +x ~/.vnc/xstartup

# Install and configure noVNC
mkdir -p ~/novnc && cd ~/novnc
git clone https://github.com/novnc/noVNC.git .
git clone https://github.com/novnc/websockify

# Start noVNC on port 6080 in background
./utils/novnc_proxy --vnc localhost:5901 &

# Ask for tunnel option
echo "Choose tunnel option:"
echo "1) Playit"
echo "2) Cloudflare Tunnel"
echo "3) Ngrok"
read -p "Enter your choice [1-3]: " tunnel_choice

# Tunnel Installers
if [ "$tunnel_choice" = "1" ]; then
  echo "Installing Playit..."
  curl -SsL https://playit-cloud.github.io/ppa/key.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null
  echo "deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./" | sudo tee /etc/apt/sources.list.d/playit-cloud.list
  sudo apt update && sudo apt install -y playit
  playit &
elif [ "$tunnel_choice" = "2" ]; then
  echo "Installing Cloudflare Tunnel..."
  curl -fsSL https://developers.cloudflare.com/cloudflare-one/static/downloads/cloudflared-linux-amd64.deb -o cloudflared.deb
  sudo dpkg -i cloudflared.deb
  echo "Run 'cloudflared tunnel login' manually to complete setup."\  cloudflared service install
elif [ "$tunnel_choice" = "3" ]; then
  echo "Installing Ngrok..."
  curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
  sudo apt update && sudo apt install -y ngrok
  echo "Paste your auth token from https://dashboard.ngrok.com"
  read -p "Auth token: " authtoken
  ngrok config add-authtoken $authtoken
  ngrok tcp 5901 &
else
  echo "Invalid option. Skipping tunnel setup."
fi

# Add keep-alive loop for 24/7 activity
cat > ~/keepalive.sh <<EOF
#!/bin/bash
while true; do
  echo "[KeepAlive] VPS is alive - \$(date)"
  sleep 300
done
EOF
chmod +x ~/keepalive.sh
nohup ~/keepalive.sh >/dev/null 2>&1 &

# Final Output
echo -e "\n✅ VPS setup complete!"
echo "🖥️ Desktop: XFCE with VNC + noVNC"
echo "🔒 Tunnel: $( [ "$tunnel_choice" = "1" ] && echo 'Playit' || ( [ "$tunnel_choice" = "2" ] && echo 'Cloudflare Tunnel' || echo 'Ngrok'))"
echo "🕒 Keep-alive loop is running 24/7"
echo "ℹ️ SSH Login: ssh -p 22673 root@147.185.221.30"
echo "🎉 Enjoy John VPS!"
