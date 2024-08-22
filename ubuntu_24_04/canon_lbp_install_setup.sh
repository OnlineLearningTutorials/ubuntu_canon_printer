#!/bin/bash

#ppd files and printer models mapping
declare -A LASERSHOT=([LBP-810]=1120 [LBP1120]=1120 [LBP1210]=1210 \
[LBP2900]=2900 [LBP3000]=3000 [LBP3010]=3050 [LBP3018]=3050 [LBP3050]=3050 \
[LBP3100]=3150 [LBP3108]=3150 [LBP3150]=3150 [LBP3200]=3200 [LBP3210]=3210 \
[LBP3250]=3250 [LBP3300]=3300 [LBP3310]=3310 [LBP3500]=3500 [LBP5000]=5000 \
[LBP5050]=5050 [LBP5100]=5100 [LBP5300]=5300 [LBP6000]=6018 [LBP6018]=6018 \
[LBP6020]=6020 [LBP6020B]=6020 [LBP6200]=6200 [LBP6300n]=6300n [LBP6300]=6300 \
[LBP6310]=6310 [LBP7010C]=7018C [LBP7018C]=7018C [LBP7200C]=7200C [LBP7210C]=7210C \
[LBP9100C]=9100C [LBP9200C]=9200C)

#Sort printer names
NAMESPRINTERS=$(echo "${!LASERSHOT[@]}" | tr ' ' '\n' | sort -n -k1.4)
echo
PS3='Please choose your printer: '
select NAMEPRINTER in $NAMESPRINTERS
do
	[ -n "$NAMEPRINTER" ] && break
done
echo "Selected printer: $NAMEPRINTER"
echo
PS3='How is the printer connected to the computer: '
select CONECTION in 'Via USB' 'Through network (LAN, NET)'
	do
		if [ "$REPLY" == "1" ]; then
			CONECTION="usb"
			while true
			do
				#Looking for a device connected to the USB port
				NODE_DEVICE=$(ls -1t /dev/usb/lp* 2> /dev/null | head -1)
				if [ -n "$NODE_DEVICE" ]; then
					#Find the serial number of that device
					PRINTER_SERIAL=$(udevadm info --attribute-walk --name=$NODE_DEVICE | sed '/./{H;$!d;};x;/ATTRS{product}=="Canon CAPT USB \(Device\|Printer\)"/!d;' | awk -F'==' '/ATTRS{serial}/{print $2}')
					#If the serial number is found, that device is a Canon printer
					[ -n "$PRINTER_SERIAL" ] && break
				fi
				echo -ne "Turn on the printer and plug in USB cable\r"
				sleep 2
			done
			PATH_DEVICE="/dev/canon$NAMEPRINTER"
			break
		elif [ "$REPLY" == "2" ]; then
			CONECTION="lan"
			read -p 'Enter the IP address of the printer: ' IP_ADDRES
			until valid_ip "$IP_ADDRES"
			do
				echo 'Invalid IP address format, enter four decimal numbers'
				echo -n 'from 0 to 255, separated by dots: '
				read IP_ADDRES
			done
			PATH_DEVICE="net:$IP_ADDRES"
			echo 'Turn on the printer and press any key'
			read -s -n1
			sleep 5
			break
		fi
	done


	echo 'Installing the printer in CUPS'
	/usr/sbin/lpadmin -p $NAMEPRINTER -P /usr/share/cups/model/CNCUPSLBP${LASERSHOT[$NAMEPRINTER]}CAPTK.ppd -v ccp://localhost:59687 -E
	echo "Setting $NAMEPRINTER as the default printer"
	/usr/sbin/lpadmin -d $NAMEPRINTER
	echo 'Registering the printer in the ccpd daemon configuration file'
	/usr/sbin/ccpdadmin -p $NAMEPRINTER -o $PATH_DEVICE
	#Verify printer installation
	installed_printer=$(ccpdadmin | grep $NAMEPRINTER | awk '{print $3}')
	if [ -n "$installed_printer" ]; then
		if [ "$CONECTION" == "usb" ]; then
			echo 'Creating a rule for the printer'
			#A rule is created to provides an alternative name (a symbolic link) to our printer so as not to depend on the changing values of lp0, lp1,...
			echo 'KERNEL=="lp[0-9]*", SUBSYSTEMS=="usb", ATTRS{serial}=='$PRINTER_SERIAL', SYMLINK+="canon'$NAMEPRINTER'"' > /etc/udev/rules.d/85-canon-capt.rules
			#Update the rules
			udevadm control --reload-rules
			#Check the created rule
			until [ -e $PATH_DEVICE ]
			do
				echo -ne "Turn off the printer, wait 2 seconds, then turn on the printer\r"
				sleep 2
			done
		fi
		echo -e "\e[2KRunning ccpd"
		service ccpd restart
		#Autoload ccpd
		update-rc.d ccpd defaults
		
		#Create captstatusui shortcut on desktop
		echo '#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Name='$NAMEPRINTER'
GenericName=Status monitor for Canon CAPT Printer
Exec=captstatusui -P '$NAMEPRINTER'
Terminal=false
Type=Application
Icon=/usr/share/icons/Humanity/devices/48/printer.svg' > "~/Desktop/$NAMEPRINTER.desktop"
		chmod 775 "${XDG_DESKTOP_DIR}/$NAMEPRINTER.desktop"
		chown $LOGIN_USER:$LOGIN_USER "${XDG_DESKTOP_DIR}/$NAMEPRINTER.desktop"
		#Install autoshutdowntool for supported models
		if [[ "${!ASDT_SUPPORTED_MODELS[@]}" =~ "$NAMEPRINTER" ]]; then
			SERIALRANGE=(${ASDT_SUPPORTED_MODELS[$NAMEPRINTER]})
			SERIALMIN=${SERIALRANGE[0]}
			SERIALMAX=${SERIALRANGE[1]}
			if [[ ${#PRINTER_SERIAL} -eq ${#SERIALMIN} && $PRINTER_SERIAL > $SERIALMIN && $PRINTER_SERIAL < $SERIALMAX || $PRINTER_SERIAL == $SERIALMIN || $PRINTER_SERIAL == $SERIALMAX ]]; then
				echo "Installing the autoshutdowntool utility"
				ASDT_FILE=autoshutdowntool_1.00-1_${ARCH}_deb.tar.gz
				if [ ! -f $ASDT_FILE ]; then
					wget -O $ASDT_FILE ${URL_ASDT[$ARCH]}
					check_error WGET $? $ASDT_FILE
				fi
				tar --gzip --extract --file=$ASDT_FILE --totals --directory=/usr/bin
			fi
		fi
		#Start captstatusui
		if [[ -n "$DISPLAY" ]] ; then
			sudo -u $LOGIN_USER nohup captstatusui -P $NAMEPRINTER > /dev/null 2>&1 &
			sleep 5
		fi
		echo 'Installation completed. Press any key to exit'
		read -s -n1
		exit 0
	else
		echo 'Driver for $NAMEPRINTER is not installed!'
		echo 'Press any key to exit'
		read -s -n1
		exit 1
	fi






