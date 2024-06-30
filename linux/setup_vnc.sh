#!/bin/bash

# Update the package list
sudo apt update

# Install XFCE4 desktop environment
sudo apt install -y xfce4 xfce4-goodies

# Install TigerVNC server
sudo apt install -y tigervnc-standalone-server tigervnc-common

# Set up VNC server configuration for the current user
mkdir -p ~/.vnc

# Create a new startup script for the VNC server
cat << 'EOF' > ~/.vnc/xstartup
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF

# Make the startup script executable
chmod +x ~/.vnc/xstartup

# Prompt the user to set a VNC password
echo "Please set a VNC password:"
vncpasswd

# Create a systemd service file for the VNC server
sudo bash -c 'cat << EOF > /etc/systemd/system/vncserver@.service
[Unit]
Description=Start TigerVNC server at startup
After=syslog.target network.target

[Service]
Type=simple
User=%i
PAMName=login
PIDFile=/home/%i/.vnc/%H:%i.pid
ExecStart=/usr/bin/vncserver :1 -geometry 1280x800 -localhost no
ExecStop=/usr/bin/vncserver -kill :1

[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd daemon to apply the new service
sudo systemctl daemon-reload

# Enable the VNC service for the current user
sudo systemctl enable vncserver@$(whoami)

# Start the VNC server
sudo systemctl start vncserver@$(whoami)

# Print the IP address of the machine
echo "Setup complete. You can now connect to this machine using a VNC client."
echo "Connect to <IP_ADDRESS>:1"
echo "Your IP address is:"
ip a | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1
