#!/bin/bash

source ./options.conf

# Official Varnish repo
# squeeze (Debian), wheezy (Debian), lucid (Ubuntu), precise (Ubuntu)
# Use "squeeze" for either Debian or Ubuntu because they appear to be symlinked to each other
LSB_RELEASE='squeeze'
VARNISH_VER='varnish-3.0'

function setup_varnish {

    # Add repo key and install Varnish
    aptitude update && aptitude -y install curl
    curl http://repo.varnish-cache.org/debian/GPG-key.txt | apt-key add -
    echo "deb http://repo.varnish-cache.org/debian/ ${LSB_RELEASE} ${VARNISH_VER}" > /etc/apt/sources.list.d/varnish.list 
    aptitude update
    aptitude -y install varnish

    # If using Apache, install mod_rpaf to get remote IP of forwarded requests
    if [ $WEBSERVER -eq 2 ]; then
        aptitude -y install libapache2-mod-rpaf
    fi

    # Create a backup copy of the original config file. Don't do anything if file exists
    if [ ! -e /etc/default/varnish_original.backup ]; then
        cp /etc/default/{varnish,varnish_original.backup}
    fi

    # Clear config file
    > /etc/default/varnish

    # Configure varnish to listen on port 80, with user specified cache size in Options.conf
    cat > /etc/default/varnish <<EOF
START=no
NFILES=131072
MEMLOCK=82000

DAEMON_OPTS="-a :80 \\
             -T localhost:6082 \\
             -f /etc/varnish/default.vcl \\
             -S /etc/varnish/secret \\
             -s malloc,${VARNISH_CACHE_SIZE}"
EOF

    # Stop Varnish first since this is only the install function
    service varnish stop

} # End function setup_varnish

function varnish_on {

    # Allow Varnish to start
    sed -i 's/START=no/START=yes/' /etc/default/varnish
    # From options.conf, nginx = 1, apache = 2
    if [ $WEBSERVER -eq 1 ]; then
        # First uncomment the listen directive and change port to 8080 (to fix the "default" vhost)
        echo 'Changing "Listen 80;" to "Listen 8080;" for vhosts in /etc/nginx/sites-available/'
        sed -i 's/#listen\s*80;/listen 8080;/' /etc/nginx/sites-available/*
        # Change the rest of the vhost to listen on port 8080
        sed -i 's/listen\s*80;/listen 8080;/' /etc/nginx/sites-available/*

        # Make sure external IP is forwarded to Nginx instead of Varnish's 127.0.0.1 IP.
        sed -i '/access_log/ i\\tset_real_ip_from 127.0.0.1\;' /etc/nginx/nginx.conf
        sed -i '/access_log/ i\\treal_ip_header X-Forwarded-For\;' /etc/nginx/nginx.conf

        service nginx restart
        sleep 2
        service varnish start
    else
        # Change Apache virtualhost ports to 8080
        echo 'Changing port 80 to 8080 for vhosts in /etc/apache2/sites-available/'
        sed -i 's/:80$/:8080/' /etc/apache2/ports.conf
        sed -i 's/Listen 80$/Listen 8080/' /etc/apache2/ports.conf
        sed -i 's/:80>$/:8080>/' /etc/apache2/sites-available/*

        apache2ctl restart
        sleep 2
        service varnish start
    fi


} # End function varnish_on


function varnish_off {

    # Deny Varnish from starting
    sed -i 's/START=yes/START=no/' /etc/default/varnish

    # From options.conf, nginx = 1, apache = 2
    if [ $WEBSERVER -eq 1 ]; then
        # Revert Nginx and virtualhost ports to 80
        echo 'Changing "Listen 8080;" to "Listen 80;" for vhosts in /etc/nginx/sites-available/'
        sed -i 's/listen\s*8080;/listen 80;/' /etc/nginx/sites-available/*

        # Remove IP forwarding.
        sed -i '/\tset_real_ip_from 127.0.0.1\;/ d' /etc/nginx/nginx.conf
        sed -i '/\treal_ip_header X-Forwarded-For\;/ d' /etc/nginx/nginx.conf

        service varnish stop
        sleep 2
        service nginx restart
    else
        #Revert apache and virtualhost ports to 80
        echo 'Changing port 8080 to 80 for vhosts in /etc/apache2/sites-available/'
        sed -i 's/:8080$/:80/' /etc/apache2/ports.conf
        sed -i 's/Listen 8080/Listen 80/' /etc/apache2/ports.conf
        sed -i 's/:8080>$/:80>/' /etc/apache2/sites-available/*

        service varnish stop
        sleep 2
        apache2ctl restart
    fi

} # End function varnish_off

# Start main program
if [ ! -n "$1" ]; then
    echo ""

    echo -n "$0"
    echo -ne "\033[36m install\033[0m"
    echo     " - Installs and configures Varnish cache."

    echo -n "$0"
    echo -ne "\033[36m on\033[0m"
    echo     " - Starts Varnish. Changes vhost ports to 8080."

    echo -n "$0"
    echo -ne "\033[36m off\033[0m"
    echo     " - Stops Varnish. Reverts vhost ports back to 80."

    echo ""
    exit
fi

case $1 in
install)
    setup_varnish
    echo -e "\033[35;1m Varnish now installed and configured with a ${VARNISH_CACHE_SIZE} cache size. \033[0m"
  ;;
on)
    varnish_on
    echo -e "\033[35;1m Varnish now enabled. \033[0m"
  ;;
off)
    varnish_off
    echo -e "\033[35;1m Varnish disabled. \033[0m"
  ;;
esac