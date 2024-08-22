#!/bin/bash

echo '************Package Installation************'
# apt-get -y update
apt install libglade2-0 libcanberra-gtk-module
apt install apparmor-utils

echo '***************8Installing 32-bit libraries required to run 64-bit printer driver*********************'
apt install libatk1.0-0:i386 libcairo2:i386 libgtk2.0-0:i386 libpango1.0-0:i386 libstdc++6:i386 libpopt0:i386 libxml2:i386 libc6:i386

echo '******************Installing common module for CUPS driver********************'
sudo dpkg -i cndrvcups-common_3.21-1_amd64.deb

echo '*****************Installing CAPT Printer Driver Module************************'
sudo dpkg -i cndrvcups-capt_2.71-1_amd64.deb

if [ ! -f /etc/init.d/ccpd ]; then
	echo "*********************** Copying ccpd file to /etc/init.d/ccpd **************"
	sudo cp ./ccpd  /etc/init.d/ccpd
fi

#Set AppArmor security profile for cupsd to complain mode
sudo aa-complain /usr/sbin/cupsd
echo '************************Restarting CUPS******************************'
sudo service cups restart
echo -e "\e[2K********************************Running ccpd****************************"
sudo service ccpd restart
sudo update-rc.d ccpd defaults








	
