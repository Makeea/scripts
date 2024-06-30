#!/bin/bash

#piactl background enable 
#piactl connect
#piactl get connectionstate
#piactl get vpnip    
#piactl get portforward
#get PIA running and remote my session through RDP without ever having to log in again. Moreover, PIA won't disconnect even after I logged out of my session.

# Enable PIA background service
piactl background enable

# Connect to PIA
piactl connect

# Wait for the connection to be established
echo "Connecting to PIA..."
while [ "$(piactl get connectionstate)" != "Connected" ]; do
    sleep 1
done

# Get the connection state
connection_state=$(piactl get connectionstate)
echo "Connection State: $connection_state"

# Get the VPN IP address
vpn_ip=$(piactl get vpnip)
echo "VPN IP: $vpn_ip"

# Get the port forwarding information
port_forward=$(piactl get portforward)
echo "Port Forwarding: $port_forward"

# Print a message indicating the script has finished
echo "PIA setup is complete and connected successfully."

# Optional: Keep the script running to prevent session disconnection
while true; do
    sleep 60
done


