#!/bin/bash

source ./options.conf

FIND_PATH="/home/*/domains/*/public_html/"
AWK_DOMAIN_POS="5"

# Used variables
DB_NAME=""
DB_USER=""
DB_USER_PASS=""
WP_FOLDER=""
DOMAIN=""
DOMAIN_OWNER=""
INSTALL_PATH="${DOMAIN}${WP_FOLDER}"
DOMAIN_URL=""

function check_mysql_installed {

    mysql=`which mysql`
    if [ -x $mysql ]; then
        echo "MySQL server installed. OK."
        return 0
    else
        return 1
    fi

} # End function check_mysql_installed


function check_wordpress_exists {

    # Need to check if existing wordpress is installed on the desired path

    if [ -e $INSTALL_PATH/wp-config.php ]; then
        return 1
    else
        return 0
    fi

} # End function check_wordpress_exists

function check_database_exists {

    # Check if database already exists

    if [ -d /var/lib/mysql/$DB_NAME ]; then
        return 1
    else
        return 0
    fi

} # End function check_database_exists

function get_latest_wordpress {

    # Downlod latest wordpress version to tmp and extract
    mkdir /tmp/wordpress
    wget -O - http://wordpress.org/latest.tar.gz | tar zxf - -C /tmp/wordpress &> /dev/null

    # Create new path for wordpress and copy files to it
    mkdir $INSTALL_PATH &> /dev/null
    mv /tmp/wordpress/wordpress/* $INSTALL_PATH

    # Create wp-config.php file
    cp $INSTALL_PATH/{wp-config-sample.php,wp-config.php}
    chown -R $DOMAIN_OWNER:$DOMAIN_OWNER $DOMAIN

    # Edit wp-config.php file with mysql data
    sed -i 's/database_name_here/'${DB_NAME}'/' $INSTALL_PATH/wp-config.php
    sed -i 's/username_here/'${DB_USER}'/' $INSTALL_PATH/wp-config.php
    sed -i ' s/password_here/'${DB_USER_PASS}'/' $INSTALL_PATH/wp-config.php

    rm -rf /tmp/wordpress

} # End function get_latest_wordpress


function add_mysqldb_and_user {

    # Form SQL query string
    Q1="CREATE DATABASE IF NOT EXISTS $DB_NAME;"
    Q2="GRANT ALL ON $DB_NAME.* TO '$DB_USER'@'localhost' IDENTIFIED BY '$DB_USER_PASS';"
    Q3="FLUSH PRIVILEGES;"
    SQL="${Q1}${Q2}${Q3}"

    # Execute the query
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "$SQL"

} # End function add_mysqldb_and_user


function find_available_domains {

    DOMAINS_AVAILABLE=0
    find $FIND_PATH -maxdepth 0 &> /dev/null

    # First check to see if there are domains available. Suppress exit status.
    if [ $? -eq 0 ]; then 
        find $FIND_PATH -maxdepth 0 > /tmp/domain.txt
        DOMAINS_AVAILABLE=`cat /tmp/domain.txt | wc -l`
    fi

    if [ $DOMAINS_AVAILABLE -eq 0 ]; then
        echo "No domains available for install. Please add a domain first."
        exit
    fi

} # End function find_available_domains

function new_or_existing_domain {

    echo "Would you like to install wordpress on a new domain or an existing one?"
    echo "1. Existing"
    echo "2. New"

    ADD_DOMAIN="a"
    until [[ $ADD_DOMAIN =~ [0-9]+ ]]; do
        echo -n "Selection :"
        read ADD_DOMAIN
    done

    if [[ "$ADD_DOMAIN" = 2 ]]; then
        echo "Please enter the domain you wish to add. Format is domain.tld."
        echo -n "Domain : "
        read DOMAIN_TO_BE_ADDED
        `/root/domainsetup.sh add $DOMAIN_TO_BE_ADDED &> /dev/null`
    fi

} # End function new_or_existing_domain


function generate_random_pass {

    LENGTH="10"
    MATRIX="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

    while [ "${n:=1}" -le "$LENGTH" ]; do
    	PASS="$PASS${MATRIX:$(($RANDOM%${#MATRIX})):1}"
    	let n+=1
    done

    DB_USER_PASS=$PASS
	
} # End function generate_random_pass


function user_input {

    # Ask user which domain to install WP

    counter=1
    DOMAINS_AVAILABLE=`cat /tmp/domain.txt | wc -l`
    echo ""
    echo "Select the domain you want to install wordpress on, 1 to $DOMAINS_AVAILABLE"
    while read LINE; do
        data=`echo $LINE | awk -F"/" '{ print $'${AWK_DOMAIN_POS}' }'`
        echo "$counter. $data"
        let counter+=1
    done < "/tmp/domain.txt"

    let counter-=1

    # Make sure user inputs a valid domain
    SELECTDOMAIN="a"
    until  [[ "$SELECTDOMAIN" =~ [0-9]+ ]] && [ $SELECTDOMAIN -gt 0 ] && [ $SELECTDOMAIN -le $counter ]; do
        echo -n "Selection (integer) : "
        read SELECTDOMAIN
    done

    # Get full system path to domain
    DOMAIN=`cat /tmp/domain.txt | awk NR==$SELECTDOMAIN`

    # Get domain URL
    DOMAIN_URL=`cat /tmp/domain.txt | awk NR==$SELECTDOMAIN | awk -F"/" '{ print $'${AWK_DOMAIN_POS}' }'`

    # Get domain owner
    DOMAIN_OWNER=`cat /tmp/domain.txt | awk NR==$SELECTDOMAIN | awk -F"/" '{ print $3 }'`
    rm -rf /tmp/domain.txt

    # Ask database name for Wordpress
    echo ""
    echo "Enter a database name for the wordpress install. E.g domainwp, wordpress, wpdomain"
    DB_NAME=""
    until  [[ "$DB_NAME" =~ [0-9a-zA-Z]+ ]]; do
        echo -n "Database name : "
        read DB_NAME
    done

    # Ask folder name for Wordpress
    echo ""
    echo "Specify a folder name if you wish to install wordpress to its own folder, \"wordpress\" is recommended. Leave blank to install to root directory."
    echo "The root directory for your selected domain = $DOMAIN"

    echo ""
    echo -n "Folder name : "
    read WP_FOLDER


    # Set database user the same as the database name
    DB_USER=$DB_NAME
    # Get full system path for installation
    INSTALL_PATH="${DOMAIN}${WP_FOLDER}"

} # End function user_input


### Main Program Begins ###

# First generate a random password for the mysql database
generate_random_pass
# Check  to see if any domains are available, or exit
find_available_domains
# Ask user database and folder settings
user_input

echo ""
echo ""
echo "Wordpress setup is ready to begin. Please check to see if the entered details are correct."
echo ""
echo "Install path = $INSTALL_PATH"
echo "Database name = $DB_NAME"
echo "Database user = $DB_USER"
echo "Database Password = $DB_USER_PASS (randomly generated)"
echo ""
echo -n "Is everything correct [y/n] : "

read DECISION

if [[ "$DECISION" = [yY] ]]; then

    check_wordpress_exists
    if [ $? -eq 1 ]; then
       echo "Wordpress already installed in your specified path. Exiting."
       exit
    fi

    check_database_exists
    if [ $? -eq 1 ]; then
       echo "Database \"$DB_NAME\" already exists. Exiting."
       exit
    fi

    check_mysql_installed
    if [ $? -eq 1 ]; then
       echo "MySQL is not installed. Exiting."
       exit
    fi

    echo ""
    echo "Downloading latest version of wordpress..."
    get_latest_wordpress
    echo "Done."

	echo "Setting up MySQL..."
    add_mysqldb_and_user
    echo "Done."
    echo ""

    echo "Wordpress installed successfully!"
    echo "Please browse http://$DOMAIN_URL/$WP_FOLDER to complete the installation."

elif  [[ "$DECISION" = [nN] ]]; then
    echo "Install aborted. Please run the script again if you want to restart the setup."
fi
