#!/bin/sh

sudo add-apt-repository ppa:mc3man/trusty-media
sudo apt- -y update
# sudo apt-get dist-upgrade
sudo apt-get install ffmpeg -y

ffmpeg -version

ffmpeg -encoders
ffmpeg -decoders

