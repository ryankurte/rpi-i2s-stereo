#!/bin/bash

sudo apt-get update
sudo apt-get dist-upgrade

echo "Enable kernel I2C/I2S"
sudo sed -i "s/#dtparam=i2s=on/dtparam=i2s=on/g" /boot/config.txt

echo "Enable I2S kernel modules"
#TODO: only do this once...
#echo "snd_soc_bcm2708" | sudo tee -a /etc/modules
#echo "snd_soc_bcm2708_i2s" | sudo tee -a /etc/modules
#echo "nbcm2708_dmaengine" | sudo tee -a /etc/modules

echo "Install kernel sources"
sudo apt-get install bc libncurses5-dev
git clone http://github.com/notro/rpi-source
cd rpi-source && python rpi-source && cd ..

echo "Build modules"
cd snd_driver && make && cd ..
cd loader && make && cd ..

echo "Configure ALSA with a virtual mono input device"
cp ./asoundrc ~/.asoundrc
sudo /etc/init.d/alsa-utils restart


