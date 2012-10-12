#!/bin/bash

# First uninstall any unnecessary packages and ensure that aptitude is installed.
apt-get update
apt-get -y install aptitude
aptitude -y install nano
aptitude -y install lsb-release
service apache2 stop
service sendmail stop
service bind9 stop
service nscd stop
aptitude -y purge nscd bind9 sendmail apache2 apache2.2-common 

echo ""
echo "Configuring /etc/apt/sources.list."
sleep 5
./setup.sh apt

echo ""
echo "Installing updates & configuring SSHD / hostname."
sleep 5
./setup.sh basic

echo ""
echo "Installing LAMP or LNMP stack."
sleep 5
./setup.sh install

echo ""
echo "Optimizing AWStats, PHP, logrotate & webserver config."
sleep 5
./setup.sh optimize

## Uncomment to secure /tmp folder
#echo ""
#echo "Securing /tmp directory."
## Use tmpdd here if your server has under 256MB memory. Tmpdd will consume a 1GB disk space for /tmp
#./setup.sh tmpfs

echo ""
echo "Installation complete!"
echo "Root login disabled."
echo "Please add a normal user now using the \"adduser\" command."
