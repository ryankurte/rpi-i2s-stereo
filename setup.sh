#!/bin/bash

# Make sure your system is up to date and install dependencies before running.
# sudo apt-get update
# sudo apt-get dist-upgrade

#set -e

echo "Install dependencies"
sudo apt-get install -yq bc libncurses5-dev

echo "Enable kernel I2C/I2S"
sudo sed -i "s/#dtparam=i2s=on/dtparam=i2s=on/g" /boot/config.txt

echo "Enable I2S kernel modules"
if ! grep -Fxq "snd_soc_bcm2708" /etc/modules; then
  echo "snd_soc_bcm2708" | sudo tee -a /etc/modules
fi

if ! grep -Fxq "snd_soc_bcm2708_i2s" /etc/modules; then
  echo "snd_soc_bcm2708_i2s" | sudo tee -a /etc/modules
fi

if ! grep -Fxq "nbcm2708_dmaengine" /etc/modules; then
  echo "nbcm2708_dmaengine" | sudo tee -a /etc/modules
fi

echo "Install kernel sources"
if [ -d "rpi-source" ]; then
  git -C rpi-source pull
else
  git clone http://github.com/notro/rpi-source
fi

cd rpi-source
python rpi-source
cd ..

pwd

echo "Build modules"
cd snd_driver && make && cd ..
cd loader && make && cd ..

echo "Configure ALSA with a virtual mono input device"
cp ./asoundrc ~/.asoundrc
sudo /etc/init.d/alsa-utils restart


