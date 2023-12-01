#!/bin/sh

# Docker Status
sudo docker container ls

# stop portainer
sudo docker stop portainer

# remove portainer
sudo docker rm portainer

# update to lastest
sudo docker pull portainer/portainer-ce:latest

# Now Install Portainer
sudo docker run -d -p 8000:8000 -p 9000:9000 -p 9443:9443 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest


# Docker Status
sudo docker container ls