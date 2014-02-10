###############################################################################################
# TuxLite - Complete LNMP/LAMP setup script for Debian/Ubuntu                                 #
# Nginx/Apache + PHP5-FPM + MySQL                                                             #
# Stack is optimized/tuned for a 256MB server                                                 #
# Email your questions to s@tuxlite.com                                                       #
###############################################################################################

source ./options.conf

# Detect distribution. Debian or Ubuntu
DISTRO=`lsb_release -i -s`
# Distribution's release. Squeeze, wheezy, precise etc
RELEASE=`lsb_release -c -s`
if  [ $DISTRO = "" ]; then
    echo -e "\033[35;1mPlease run 'aptitude -y install lsb-release' before using this script.\033[0m"
    exit 1
fi


#### Functions Begin ####

function basic_server_setup {

    aptitude update && aptitude -y safe-upgrade

    # Reconfigure sshd - change port and disable root login
    sed -i 's/^Port [0-9]*/Port '${SSHD_PORT}'/' /etc/ssh/sshd_config
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    service ssh reload

    # Set hostname and FQDN
    sed -i 's/'${SERVER_IP}'.*/'${SERVER_IP}' '${HOSTNAME_FQDN}' '${HOSTNAME}'/' /etc/hosts
    echo "$HOSTNAME" > /etc/hostname

    if [ $DISTRO = "Debian" ]; then
        # Debian system, use hostname.sh
        service hostname.sh start
    else
        # Ubuntu system, use hostname
        service hostname start
    fi

    # Basic hardening of sysctl.conf
    sed -i 's/^#net.ipv4.conf.all.accept_source_route = 0/net.ipv4.conf.all.accept_source_route = 0/' /etc/sysctl.conf
    sed -i 's/^net.ipv4.conf.all.accept_source_route = 1/net.ipv4.conf.all.accept_source_route = 0/' /etc/sysctl.conf
    sed -i 's/^#net.ipv6.conf.all.accept_source_route = 0/net.ipv6.conf.all.accept_source_route = 0/' /etc/sysctl.conf
    sed -i 's/^net.ipv6.conf.all.accept_source_route = 1/net.ipv6.conf.all.accept_source_route = 0/' /etc/sysctl.conf

    echo -e "\033[35;1m Root login disabled, SSH port set to $SSHD_PORT. Hostname set to $HOSTNAME and FQDN to $HOSTNAME_FQDN. \033[0m"
    echo -e "\033[35;1m Remember to create a normal user account for login or you will be locked out from your box! \033[0m"

} # End function basic_server_setup


function setup_apt {

    # If user enables apt option in options.conf
    if [ $CONFIGURE_APT = "yes" ]; then
        cp /etc/apt/{sources.list,sources.list.bak}

        if [ $DISTRO = "Debian" ]; then
            # Debian system, use Debian sources.list
            echo -e "\033[35;1mConfiguring APT for Debian. \033[0m"
            cat > /etc/apt/sources.list <<EOF
# Main repo
deb http://http.debian.net/debian $RELEASE main non-free contrib
deb-src http://http.debian.net/debian $RELEASE main non-free contrib
# Security
deb http://security.debian.org/ $RELEASE/updates main contrib non-free
deb-src http://security.debian.org/ $RELEASE/updates main contrib non-free

EOF
        fi # End if DISTRO = Debian


        if [ $DISTRO = "Ubuntu" ]; then
            # Ubuntu system, use Ubuntu sources.list
            echo -e "\033[35;1mConfiguring APT for Ubuntu. \033[0m"
            cat > /etc/apt/sources.list <<EOF
# Main repo
deb mirror://mirrors.ubuntu.com/mirrors.txt $RELEASE main restricted universe multiverse
deb-src mirror://mirrors.ubuntu.com/mirrors.txt $RELEASE main restricted universe multiverse

# Security & updates
deb mirror://mirrors.ubuntu.com/mirrors.txt $RELEASE-updates main restricted universe multiverse
deb-src mirror://mirrors.ubuntu.com/mirrors.txt $RELEASE-updates main restricted universe multiverse
deb mirror://mirrors.ubuntu.com/mirrors.txt $RELEASE-security main restricted universe multiverse
deb-src mirror://mirrors.ubuntu.com/mirrors.txt $RELEASE-security main restricted universe multiverse

EOF
        fi # End if DISTRO = Ubuntu


        #  Report error if detected distro is not yet supported
        if [ $DISTRO  != "Ubuntu" ] && [ $DISTRO  != "Debian" ]; then
            echo -e "\033[35;1mSorry, Distro: $DISTRO and Release: $RELEASE is not supported at this time. \033[0m"
            exit 1
        fi

    fi # End if CONFIGURE_APT = yes


    ## Third party mirrors ##

    # Need to add Dotdeb repo for installing PHP5-FPM when using Debian 6.0 (squeeze)
    if  [ $DISTRO = "Debian" ] && [ $RELEASE = "squeeze" ]; then
        echo -e "\033[35;1mEnabling DotDeb repo for Debian 6.0 Squeeze. \033[0m"
        cat > /etc/apt/sources.list.d/dotdeb.list <<EOF
# Dotdeb
deb http://packages.dotdeb.org squeeze all
deb-src http://packages.dotdeb.org squeeze all

EOF
        wget http://www.dotdeb.org/dotdeb.gpg
        cat dotdeb.gpg | apt-key add -
    fi # End if DISTRO = Debian && RELEASE = squeeze


    # If user wants to install nginx from official repo and webserver=nginx
    if  [ $USE_NGINX_ORG_REPO = "yes" ] && [ $WEBSERVER = 1 ]; then
        echo -e "\033[35;1mEnabling nginx.org repo for Debian $RELEASE. \033[0m"
        cat > /etc/apt/sources.list.d/nginx.list <<EOF
# Official Nginx.org repository
deb http://nginx.org/packages/`echo $DISTRO | tr '[:upper:]' '[:lower:]'`/ $RELEASE nginx
deb-src http://nginx.org/packages/`echo $DISTRO | tr '[:upper:]' '[:lower:]'`/ $RELEASE nginx

EOF

        # Set APT pinning for Nginx package
        cat > /etc/apt/preferences.d/Nginx <<EOF
# Prevent potential conflict with main repo/dotdeb 
# Always install from official nginx.org repo
Package: nginx
Pin: origin nginx.org
Pin-Priority: 1000

EOF
        wget http://nginx.org/packages/keys/nginx_signing.key
        cat nginx_signing.key | apt-key add -
    fi # End if USE_NGINX_ORG_REPO = yes && WEBSERVER = 1


    # If user wants to install MariaDB instead of MySQL
    if [ $INSTALL_MARIADB = 'yes' ]; then
        echo -e "\033[35;1mEnabling MariaDB.org repo for $DISTRO $RELEASE. \033[0m"
        cat > /etc/apt/sources.list.d/MariaDB.list <<EOF
# http://mariadb.org/mariadb/repositories/
deb $MARIADB_REPO`echo $DISTRO | tr [:upper:] [:lower:]` $RELEASE main
deb-src $MARIADB_REPO`echo $DISTRO | tr [:upper:] [:lower:]` $RELEASE main

EOF

        # Set APT pinning for MariaDB packages
        cat > /etc/apt/preferences.d/MariaDB <<EOF
# Prevent potential conflict with main repo that causes
# MariaDB to be uninstalled when upgrading mysql-common
Package: *
Pin: origin $MARIADB_REPO_HOSTNAME
Pin-Priority: 1000

EOF

        # Import MariaDB signing key
        apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
    fi # End if INSTALL_MARIADB = yes

    aptitude update
    echo -e "\033[35;1m Successfully configured /etc/apt/sources.list \033[0m"

} # End function setup_apt


function install_webserver {

    # From options.conf, nginx = 1, apache = 2
    if [ $WEBSERVER = 1 ]; then
        aptitude -y install nginx

        if  [ $USE_NGINX_ORG_REPO = "yes" ]; then
            mkdir /etc/nginx/sites-available
            mkdir /etc/nginx/sites-enabled

           # Disable vhost that isn't in the sites-available folder. Put a hash in front of any line.
           sed -i 's/^[^#]/#&/' /etc/nginx/conf.d/default.conf

           # Enable default vhost in /etc/nginx/sites-available
           ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
        fi

        # Add a catch-all default vhost
        cat ./config/nginx_default_vhost.conf > /etc/nginx/sites-available/default

        # Change default vhost root directory to /usr/share/nginx/html;
        sed -i 's/\(root \/usr\/share\/nginx\/\).*/\1html;/' /etc/nginx/sites-available/default
    else
        aptitude -y install libapache2-mod-fastcgi apache2-mpm-event

        a2dismod php4
        a2dismod php5
        a2dismod fcgid
        a2enmod actions
        a2enmod fastcgi
        a2enmod ssl
        a2enmod rewrite

        cat ./config/fastcgi.conf > /etc/apache2/mods-available/fastcgi.conf

        # Create the virtual directory for the external server
        mkdir -p /srv/www/fcgi-bin.d
    fi

} # End function install_webserver


function install_php {

    # Install PHP packages and extensions specified in options.conf
    aptitude -y install $PHP_BASE
    aptitude -y install $PHP_EXTRAS

} # End function install_php


function install_extras {

    if [ $AWSTATS_ENABLE = 'yes' ]; then
        aptitude -y install awstats
    fi

    # Install any other packages specified in options.conf
    aptitude -y install $MISC_PACKAGES

} # End function install_extras


function install_mysql {

    echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections

    if [ $INSTALL_MARIADB = 'yes' ]; then
        aptitude -y install mariadb-server mariadb-client
    else
        aptitude -y install mysql-server mysql-client
    fi

    echo -e "\033[35;1m Securing MySQL... \033[0m"
    sleep 5

    aptitude -y install expect

    SECURE_MYSQL=$(expect -c "
        set timeout 10
        spawn mysql_secure_installation
        expect \"Enter current password for root (enter for none):\"
        send \"$MYSQL_ROOT_PASSWORD\r\"
        expect \"Change the root password?\"
        send \"n\r\"
        expect \"Remove anonymous users?\"
        send \"y\r\"
        expect \"Disallow root login remotely?\"
        send \"y\r\"
        expect \"Remove test database and access to it?\"
        send \"y\r\"
        expect \"Reload privilege tables now?\"
        send \"y\r\"
        expect eof
    ")

    echo "$SECURE_MYSQL"
    aptitude -y purge expect

} # End function install_mysql


function optimize_stack {

    # If using Nginx, copy over nginx.conf
    if [ $WEBSERVER = 1 ]; then
        cat ./config/nginx.conf > /etc/nginx/nginx.conf

        # Change nginx user from  "www-data" to "nginx". Not really necessary
        # because "www-data" user is created when installing PHP5-FPM
        if  [ $USE_NGINX_ORG_REPO = "yes" ]; then
            sed -i 's/^user\s*www-data/user nginx/' /etc/nginx/nginx.conf
        fi

        # Change logrotate for nginx log files to keep 10 days worth of logs
        nginx_file=`find /etc/logrotate.d/ -maxdepth 1 -name "nginx*"`
        sed -i 's/\trotate .*/\trotate 10/' $nginx_file

    # If using Apache, copy over apache2.conf
    else
        cat ./config/apache2.conf > /etc/apache2/apache2.conf

        # Change logrotate for Apache2 log files to keep 10 days worth of logs
        sed -i 's/\tweekly/\tdaily/' /etc/logrotate.d/apache2
        sed -i 's/\trotate .*/\trotate 10/' /etc/logrotate.d/apache2

        # Remove Apache server information from headers.
        sed -i 's/ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf.d/security
        sed -i 's/ServerSignature .*/ServerSignature Off/' /etc/apache2/conf.d/security

        # Add *:443 to ports.conf
        cat ./config/apache2_ports.conf > /etc/apache2/ports.conf
    fi

    if [ $AWSTATS_ENABLE = 'yes' ]; then
        # Configure AWStats
        temp=`grep -i sitedomain /etc/awstats/awstats.conf.local | wc -l`
        if [ $temp -lt 1 ]; then
            echo SiteDomain="$HOSTNAME_FQDN" >> /etc/awstats/awstats.conf.local
        fi
        # Disable Awstats from executing every 10 minutes. Put a hash in front of any line.
        sed -i 's/^[^#]/#&/' /etc/cron.d/awstats
    fi

    service php5-fpm stop
    php_fpm_conf="/etc/php5/fpm/pool.d/www.conf"
    # Limit FPM processes
    sed -i 's/^pm.max_children.*/pm.max_children = '${FPM_MAX_CHILDREN}'/' $php_fpm_conf
    sed -i 's/^pm.start_servers.*/pm.start_servers = '${FPM_START_SERVERS}'/' $php_fpm_conf
    sed -i 's/^pm.min_spare_servers.*/pm.min_spare_servers = '${FPM_MIN_SPARE_SERVERS}'/' $php_fpm_conf
    sed -i 's/^pm.max_spare_servers.*/pm.max_spare_servers = '${FPM_MAX_SPARE_SERVERS}'/' $php_fpm_conf
    sed -i 's/\;pm.max_requests.*/pm.max_requests = '${FPM_MAX_REQUESTS}'/' $php_fpm_conf
    # Change to socket connection for better performance
    sed -i 's/^listen =.*/listen = \/var\/run\/php5-fpm-www-data.sock/' $php_fpm_conf

    php_ini_dir="/etc/php5/fpm/php.ini"
    # Tweak php.ini based on input in options.conf
    sed -i 's/^max_execution_time.*/max_execution_time = '${PHP_MAX_EXECUTION_TIME}'/' $php_ini_dir
    sed -i 's/^memory_limit.*/memory_limit = '${PHP_MEMORY_LIMIT}'/' $php_ini_dir
    sed -i 's/^max_input_time.*/max_input_time = '${PHP_MAX_INPUT_TIME}'/' $php_ini_dir
    sed -i 's/^post_max_size.*/post_max_size = '${PHP_POST_MAX_SIZE}'/' $php_ini_dir
    sed -i 's/^upload_max_filesize.*/upload_max_filesize = '${PHP_UPLOAD_MAX_FILESIZE}'/' $php_ini_dir
    sed -i 's/^expose_php.*/expose_php = Off/' $php_ini_dir
    sed -i 's/^disable_functions.*/disable_functions = exec,system,passthru,shell_exec,escapeshellarg,escapeshellcmd,proc_close,proc_open,dl,popen,show_source/' $php_ini_dir

    # Generating self signed SSL certs for securing phpMyAdmin, script logins etc
    echo -e " "
    echo -e "\033[35;1m Generating self signed SSL cert... \033[0m"
    mkdir /etc/ssl/localcerts

    aptitude -y install expect

    GENERATE_CERT=$(expect -c "
        set timeout 10
        spawn openssl req -new -x509 -days 3650 -nodes -out /etc/ssl/localcerts/webserver.pem -keyout /etc/ssl/localcerts/webserver.key
        expect \"Country Name (2 letter code) \[AU\]:\"
        send \"\r\"
        expect \"State or Province Name (full name) \[Some-State\]:\"
        send \"\r\"
        expect \"Locality Name (eg, city) \[\]:\"
        send \"\r\"
        expect \"Organization Name (eg, company) \[Internet Widgits Pty Ltd\]:\"
        send \"\r\"
        expect \"Organizational Unit Name (eg, section) \[\]:\"
        send \"\r\"
        expect \"Common Name (eg, YOUR name) \[\]:\"
        send \"\r\"
        expect \"Email Address \[\]:\"
        send \"\r\"
        expect eof
    ")

    echo "$GENERATE_CERT"
    aptitude -y purge expect

    # Tweak my.cnf. Commented out. Best to let users configure my.cnf on their own
    #cp /etc/mysql/{my.cnf,my.cnf.bak}
    #if [ -e /usr/share/doc/mysql-server-5.1/examples/my-medium.cnf.gz ]; then
    #gunzip /usr/share/doc/mysql-server-5.1/examples/my-medium.cnf.gz
    #cp /usr/share/doc/mysql-server-5.1/examples/my-medium.cnf /etc/mysql/my.cnf
    #else
    #gunzip /usr/share/doc/mysql-server-5.0/examples/my-medium.cnf.gz
    #cp /usr/share/doc/mysql-server-5.0/examples/my-medium.cnf /etc/mysql/my.cnf
    #fi
    #sed -i '/myisam_sort_buffer_size/ a\skip-innodb' /etc/mysql/my.cnf
    #sleep 1
    #service mysql restart

    restart_webserver
    sleep 2
    service php5-fpm start
    sleep 2
    service php5-fpm restart
    echo -e "\033[35;1m Optimize complete! \033[0m"

} # End function optimize


function install_postfix {

    # Install postfix
    echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
    echo "postfix postfix/mailname string $HOSTNAME_FQDN" | debconf-set-selections
    echo "postfix postfix/destinations string localhost.localdomain, localhost" | debconf-set-selections
    aptitude -y install postfix

    # Allow mail delivery from localhost only
    /usr/sbin/postconf -e "inet_interfaces = loopback-only"

    sleep 1
    postfix stop
    sleep 1
    postfix start

} # End function install_postfix



function install_dbgui {

    # If user selected phpMyAdmin in options.conf
    if [ $DB_GUI = 1  ]; then
        mkdir /tmp/phpmyadmin
        PMA_VER="`wget -q -O - http://www.phpmyadmin.net/home_page/downloads.php|grep -m 1 '<h2>phpMyAdmin'|sed -r 's/^[^3-9]*([0-9.]*).*/\1/'`"
        wget -O - "http://sourceforge.net/projects/phpmyadmin/files/phpMyAdmin/${PMA_VER}/phpMyAdmin-${PMA_VER}-all-languages.tar.gz" | tar zxf - -C /tmp/phpmyadmin

        # Check exit status to see if download is successful
        if [ $? = 0  ]; then
            mkdir /usr/local/share/phpmyadmin
            rm -rf /usr/local/share/phpmyadmin/*
            cp -Rpf /tmp/phpmyadmin/*/* /usr/local/share/phpmyadmin
            cp /usr/local/share/phpmyadmin/{config.sample.inc.php,config.inc.php}
            rm -rf /tmp/phpmyadmin

            # Generate random blowfish string
            LENGTH="20"
            MATRIX="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
            while [ "${n:=1}" -le "$LENGTH" ]; do
                BLOWFISH="$BLOWFISH${MATRIX:$(($RANDOM%${#MATRIX})):1}"
                let n+=1
            done

            # Configure phpmyadmin blowfish variable
            sed -i "s/blowfish_secret'] = ''/blowfish_secret'] = \'$BLOWFISH\'/"  /usr/local/share/phpmyadmin/config.inc.php
            echo -e "\033[35;1mphpMyAdmin installed/upgraded.\033[0m"
        else
            echo -e "\033[35;1mInstall/upgrade failed. Perhaps phpMyAdmin download link is temporarily down. Update link in options.conf and try again.\033[0m"
        fi

    else # User selected Adminer

        mkdir -p /usr/local/share/adminer
        cd /usr/local/share/adminer
        rm -rf /usr/local/share/adminer/*
        wget http://www.adminer.org/latest.php
        if [ $? = 0  ]; then
            mv latest.php index.php
            echo -e "\033[35;1m Adminer installed. \033[0m"
        else
            echo -e "\033[35;1mInstall/upgrade failed. Perhaps http://adminer.org is down. Try again later.\033[0m"
        fi
        cd - &> /dev/null
    fi # End if DB_GUI

} # End function install_dbgui


function check_tmp_secured {

    temp1=`grep -w "/var/tempFS /tmp ext3 loop,nosuid,noexec,rw 0 0" /etc/fstab | wc -l`
    temp2=`grep -w "tmpfs /tmp tmpfs rw,noexec,nosuid 0 0" /etc/fstab | wc -l`

    if [ $temp1  -gt 0 ] || [ $temp2 -gt 0 ]; then
        return 1
    else
        return 0
    fi

} # End function check_tmp_secured


function secure_tmp_tmpfs {

    cp /etc/fstab /etc/fstab.bak
    # Backup /tmp
    cp -Rpf /tmp /tmpbackup

    rm -rf /tmp
    mkdir /tmp

    mount -t tmpfs -o rw,noexec,nosuid tmpfs /tmp
    chmod 1777 /tmp
    echo "tmpfs /tmp tmpfs rw,noexec,nosuid 0 0" >> /etc/fstab

    # Restore /tmp
    cp -Rpf /tmpbackup/* /tmp/ >/dev/null 2>&1

    #Remove old tmp dir
    rm -rf /tmpbackup

    # Backup /var/tmp and link it to /tmp
    mv /var/tmp /var/tmpbackup
    ln -s /tmp /var/tmp

    # Copy the old data back
    cp -Rpf /var/tmpold/* /tmp/ >/dev/null 2>&1
    # Remove old tmp dir
    rm -rf /var/tmpbackup

    echo -e "\033[35;1m /tmp and /var/tmp secured using tmpfs. \033[0m"

} # End function secure_tmp_tmpfs


function secure_tmp_dd {

    cp /etc/fstab /etc/fstab.bak

    # Create 1GB space for /tmp, change count if you want smaller/larger size
    dd if=/dev/zero of=/var/tempFS bs=1024 count=$TMP_SIZE
    # Make space as a ext3 filesystem
    /sbin/mkfs.ext3 /var/tempFS

    # Backup /tmp
    cp -Rpf /tmp /tmpbackup

    # Secure /tmp
    mount -o loop,noexec,nosuid,rw /var/tempFS /tmp
    chmod 1777 /tmp
    echo "/var/tempFS /tmp ext3 loop,nosuid,noexec,rw 0 0" >> /etc/fstab

    # Restore /tmp
    cp -Rpf /tmpbackup/* /tmp/ >/dev/null 2>&1

    # Remove old tmp dir
    rm -rf /tmpbackup

    # Backup /var/tmp and link it to /tmp
    mv /var/tmp /var/tmpbackup
    ln -s /tmp /var/tmp

    # Copy the old data back
    cp -Rpf /var/tmpold/* /tmp/ >/dev/null 2>&1
    # Remove old tmp dir
    rm -rf /var/tmpbackup

    echo -e "\033[35;1m /tmp and /var/tmp secured using file created using dd. \033[0m"

} # End function secure_tmp_tmpdd


function restart_webserver {

    # From options.conf, nginx = 1, apache = 2
    if [ $WEBSERVER = 1 ]; then
        service nginx restart
    else
        apache2ctl graceful
    fi

} # End function restart_webserver



#### Main program begins ####

# Show Menu
if [ ! -n "$1" ]; then
    echo ""
    echo -e  "\033[35;1mNOTICE: Edit options.conf before using\033[0m"
    echo -e  "\033[35;1mA standard setup would be: apt + basic + install + optimize\033[0m"
    echo ""
    echo -e  "\033[35;1mSelect from the options below to use this script:- \033[0m"

    echo -n "$0"
    echo -ne "\033[36m apt\033[0m"
    echo     " - Reconfigure or reset /etc/apt/sources.list."

    echo -n  "$0"
    echo -ne "\033[36m basic\033[0m"
    echo     " - Disable root SSH logins, change SSH port and set hostname."

    echo -n "$0"
    echo -ne "\033[36m install\033[0m"
    echo     " - Installs LNMP or LAMP stack. Also installs Postfix MTA."

    echo -n "$0"
    echo -ne "\033[36m optimize\033[0m"
    echo     " - Optimizes webserver.conf, php.ini, AWStats & logrotate. Also generates self signed SSL certs."

    echo -n "$0"
    echo -ne "\033[36m dbgui\033[0m"
    echo     " - Installs or updates Adminer/phpMyAdmin."

    echo -n "$0"
    echo -ne "\033[36m tmpfs\033[0m"
    echo     " - Secures /tmp and /var/tmp using tmpfs. Not recommended for servers with less than 512MB dedicated RAM."

    echo -n "$0"
    echo -ne "\033[36m tmpdd\033[0m"
    echo     " - Secures /tmp and /var/tmp using a file created on disk. Tmp size is defined in options.conf."

    echo ""
    exit
fi
# End Show Menu


case $1 in
apt)
    setup_apt
    ;;
basic)
    basic_server_setup
    ;;
install)
    install_webserver
    install_mysql
    install_php
    install_extras
    install_postfix
    restart_webserver
    service php5-fpm restart
    echo -e "\033[35;1m Webserver + PHP-FPM + MySQL install complete! \033[0m"
    ;;
optimize)
    optimize_stack
    ;;
dbgui)
    install_dbgui
    ;;
tmpdd)
    check_tmp_secured
    if [ $? = 0  ]; then
        secure_tmp_dd
    else
        echo -e "\033[35;1mFunction canceled. /tmp already secured. \033[0m"
    fi
    ;;
tmpfs)
    check_tmp_secured
    if [ $? = 0  ]; then
        secure_tmp_tmpfs
    else
        echo -e "\033[35;1mFunction canceled. /tmp already secured. \033[0m"
    fi
    ;;
esac


