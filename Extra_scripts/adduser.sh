#!/bin/bash
# Script to add a user to Linux system
# -------------------------------------------------------------------------
# Copyright (c) 2007 nixCraft project <http://bash.cyberciti.biz/>
# This script is licensed under GNU GPL version 2.0 or above
# Comment/suggestion: <vivek at nixCraft DOT com>
# -------------------------------------------------------------------------
# See url for more info:
# http://www.cyberciti.biz/tips/howto-write-shell-script-to-add-user.html
# -------------------------------------------------------------------------
if [ $(id -u) -eq 0 ]; then
	read -p "Enter username : " USERNAME
	read -s -p "Enter password : " PASSWORD
	egrep "^$USERNAME" /etc/passwd >/dev/null
	if [ $? -eq 0 ]; then
		echo "$USERNAME exists!"
		exit 1
	else
		pass=$(perl -e 'print crypt($ARGV[0], "password")' $PASSWORD)
		useradd -m -p $pass $USERNAME
		[ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
	fi
else
	echo "Only root may add a user to the system"
	exit 2
fi
# -------------------------------------------------------------------------
# End script to add a user to Linux system
# -------------------------------------------------------------------------

# Add $USERNAME to SSH AllowUsers
echo "AllowUsers $USERNAME" >> /etc/ssh/sshd_config

read -s -p "Enter user publickey : " PUBLICKEY

# Add  $USERNAME ssh key
mkdir /home/$USERNAME/.ssh
touch /home/$USERNAME/.ssh/authorized_keys
echo $PUBLICKEY >> /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys

# Check if adding key succeeded
[ -f /home/$USERNAME/.ssh/authorized_keys ] && echo "Adding publickey succeeded" || echo "Adding publickey failed"

sed -i "s/#AuthorizedKeysFile/AuthorizedKeysFile/g" /etc/ssh/sshd_config
