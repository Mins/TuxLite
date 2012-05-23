#!/bin/bash
## test to see if logic works still.

# Operating system
OS=`lsb_release -i -s`
# Release
R=`lsb_release -c -s`

 
function setup_apt {

    cp /etc/apt/{sources.list,sources.list.bak}

    if [ $OS  == "Debian" ]; then
        echo -e "\033[35;1m Its Debian \033[0m"
        # Debian system, use Debian sources.list
        cat > /etc/apt/sources.list <<EOF
# Main repo
deb http://ftp.$APT_REGION.debian.org/debian $R main non-free contrib
deb-src  http://ftp.$APT_REGION.debian.org/debian $R main non-free contrib

# Security
deb http://security.debian.org/ $R/updates main contrib non-free
deb-src http://security.debian.org/ $R/updates main contrib non-free

EOF

    else 
        if [ $OS  == "Ubuntu" ]; then 
        echo -e "\033[35;1m Its Ubuntu \033[0m"
    # Otherwise use Ubuntu sources.list

        cat > /etc/apt/sources.list <<EOF
# Main repo
deb http://$APT_REGION.archive.ubuntu.com/ubuntu/ $R main restricted universe multiverse
deb-src http://$APT_REGION.archive.ubuntu.com/ubuntu/ $R main restricted universe

# Security & updates
deb http://$APT_REGION.archive.ubuntu.com/ubuntu/ $R-updates main restricted universe multiverse
deb-src http://$APT_REGION.archive.ubuntu.com/ubuntu/ $R-updates main restricted universe
deb http://security.ubuntu.com/ubuntu $R-security main restricted universe
deb-src http://security.ubuntu.com/ubuntu $R-security main restricted universe

EOF
        else
             
            if [ $OS  != "Ubuntu" ] && [ $OS  != "Debian"  ]; then
                # throw an error if its not supported os, 
                echo -e "\033[35;1m Sorry, OS: '"$OS"' and Version: '"$R"' are not supported at this time. \033[0m"
                exit
            fi
        fi # End if 
    fi
    # Need to add Dotdeb repo for PHP5-FPM when using Debian 6.0
    if [ $R = "squeeze" ]; then
         echo -e "\033[35;1m Its Debian '"$R"' \033[0m"
        cat >> /etc/apt/sources.list <<EOF
# Dotdeb
deb http://packages.dotdeb.org stable all
deb-src http://packages.dotdeb.org stable all

EOF
        wget http://www.dotdeb.org/dotdeb.gpg
        cat dotdeb.gpg | apt-key add -
        aptitude update
    fi

    echo -e "\033[35;1m Successfully configured /etc/apt/sources.list\033[0m"

} # End function setup_apt

setup_apt