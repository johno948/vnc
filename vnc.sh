#!/bin/bash

# === JOHN VPS Setup ===
echo "=================================="
echo "      🚀 Starting John VPS Setup"
echo "=================================="

# Update system
apt update -y && apt upgrade -y

# Install essentials
apt install -y curl sudo wget git net-tools htop neofetch nano unzip ufw

# Set hostname
hostnamectl set-hostname john-vps

# Setup MOTD banner
echo 'echo -e "\e[1;32mWelcome to JOHN VPS!\e[0m"' >> /etc/profile.d/john-vps-banner.sh
chmod +x /etc/profile.d/john-vps-banner.sh

# Install XFCE, VNC, and noVNC
apt install -y xfce4 xfce4-goodies tightvncserver
apt install -y websockify novnc python3-websockify

# Set up VNC password (default: 123456)
mkdir -p ~/.vnc
echo "123456" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# Create VNC startup script
cat > ~/.vnc/xstartup <<EOF
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF
chmod +x ~/.vnc/xstartup

# Start VNC server once to generate files
vncserver :1 -geometry 1280x720 -depth 24
vncserver -kill :1

# Create noVNC startup script
cat > /usr/local/bin/novnc-start <<EOF
#!/bin/bash
vncserver :1 -geometry 1280x720 -depth 24
websockify --web=/usr/share/novnc/ 6080 localhost:5901
EOF
chmod +x /usr/local/bin/novnc-start

# Ask user about tunnel option
echo ""
echo "Choose Tunnel Method:"
echo "[1] Cloudflare Tunnel"
echo "[2] Ngrok"
echo "[3] Playit Tunnel"
echo "[4] None"
read -p "Enter option [1-4]: " tunnel_option

case $tunnel_option in
  1)
    echo "Installing Cloudflare Tunnel..."
    curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
    echo "Run: cloudflared tunnel --url http://localhost:6080"
    ;;
  2)
    echo "Installing Ngrok..."
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list
    apt update && apt install ngrok
    echo "Run: ngrok http 6080"
    ;;
  3)
    echo "Installing Playit Tunnel..."
    wget https://playit-cloud.github.io/hosted/client/playit-linux.zip
    unzip playit-linux.zip
    chmod +x playit
    mv playit /usr/local/bin/
    echo "Run: playit"
    ;;
  *)
    echo "Skipping tunnel installation."
    ;;
esac

# 24/7 keep-alive script
cat > /usr/local/bin/keep-alive.sh <<EOF
#!/bin/bash
while true; do
  echo "🟢 John VPS running - $(date)"
  sleep 300
done
EOF
chmod +x /usr/local/bin/keep-alive.sh
nohup bash /usr/local/bin/keep-alive.sh >/dev/null 2>&1 &

# Auto-start info
ip=$(curl -s ifconfig.me)
port=$(ss -tnlp | grep ssh | awk '{print $4}' | head -n1 | cut -d: -f2)
echo ""
echo "✅ Setup Complete!"
echo "Login via:"
echo ""
echo "👉 ssh -p $port root@$ip"
echo "🖥️  Then run: novnc-start"
echo ""

# Show system info
neofetch
