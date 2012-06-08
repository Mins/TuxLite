#!/bin/bash

FIND_PATH="/home/*/domains/*"
# Used to filter database name from its full system path
# (1)/var(2)/lib(3)/mysql(4)/dbname(5)
AWK_DB_POS="5"
# Used to filter domain name from its full system path
# E.g. (1)/home(2)/john(3)/domains(4)/johndomain.com(5)
AWK_DOMAIN_POS="5"


source ./options.conf


function ask_interval {

    # Ask user how often do they want the backup jobs to run?
    echo "How often do you want the backups/cleanups to run?"
    echo "1. Daily"
    echo "2. Weekly"
    echo "3. Monthly"

    # Initialize variable with an alphabet
    SELECT_INTERVAL="a"
    # Keep looping until user enters a number that is greater than 0 and less than 3
    until  [[ "$SELECT_INTERVAL" =~ [0-9]+ ]] && [ $SELECT_INTERVAL -gt 0 ] && [ $SELECT_INTERVAL -le 3 ]; do
        echo -n "Selection (integer) : "
        read SELECT_INTERVAL
    done

    if [ $SELECT_INTERVAL -eq 1 ]; then
        INTERVAL="daily"
    elif [ $SELECT_INTERVAL -eq 2 ]; then
        INTERVAL="weekly"
    elif [ $SELECT_INTERVAL -eq 3 ]; then
        INTERVAL="monthly"
    fi
} # End of ask_interval

function find_available_domains {

    # Initialize variable
    DOMAINS_AVAILABLE=0

    # First check to see if there are domains available. Suppress exit status.
    find $FIND_PATH -maxdepth 0 &> /dev/null

    # If exit status is 0, there are domains available
    # Collect available domains to a temporary file
    if [ $? -eq 0 ]; then
        find $FIND_PATH -maxdepth 0 > /tmp/domain.txt
        DOMAINS_AVAILABLE=`cat /tmp/domain.txt | wc -l`
    # Remove fcgi-bin directory as available domain. #Not used for multiuser scripts
        # sed -i '/\/srv\/www\/fcgi-bin.d/ d' /tmp/domain.txt
    fi

    # Exit status of find command is 1, ask user to add domain first
    if [ $DOMAINS_AVAILABLE -eq 0 ]; then
        echo "No domains available for backup. Please add a domain first."
        exit
    fi

} # End of find_available_domains

function find_available_databases {

    # Initialize variable
    DATABASES_AVAILABLE=0

    # First search for available mysql databases
    find /var/lib/mysql/* -maxdepth 0 -type d > /tmp/database.txt

    # Remove mysql and phpmyadmin as available databases
    sed -i '/\/var\/lib\/mysql\/mysql/ d' /tmp/database.txt
    sed -i '/\/var\/lib\/mysql\/phpmyadmin/ d' /tmp/database.txt
    DATABASES_AVAILABLE=`cat /tmp/database.txt | wc -l`

    # No databases found, ask user to add database first
    if [ $DATABASES_AVAILABLE -eq 0 ]; then
        echo "No databases available for backup. Please add a database first."
        exit
    fi

} # End of find_available_databases


function create_backup_directory {

    # First check if Linux user exists
    # If yes, create backup folders
    if [ -d "/home/$USER" ]; then
        mkdir -p /home/$USER/backup/{databases,domains}
        chown -R $USER:$USER /home/$USER/backup
        echo -e "\033[35;1mBackup folders created in /home/$USER/backup.\033[0m"
    else
        # If not, exit and inform user
        echo -e "\033[35;1mERROR: User /home/$USER doesn't exist.\033[0m"
        exit 1
    fi

} # End of create_backup_directory

function cron_backupdb {

    # First check if backup location exists. Exit if not found.
    if [ ! -d "/home/$USER/backup/databases" ]; then
        echo -e "\033[35;1mERROR: Database folder /home/$USER/backup/databases doesn't exist, please create it first.\033[0m"
        exit 1
    fi

    # Initialize selection value when listing available databases to user
    counter=1
    # Check how many databases are available
    DB_AVAILABLE=`cat /tmp/database.txt | wc -l`

    # Print out available databases
    echo ""
    echo "Select the database you want to backup, 1 to $DB_AVAILABLE"
    while read LINE; do
        # For each domain path, use AWK to get only the domain name and leave out the full path
        data=`echo $LINE | awk -F"/" '{ print $'${AWK_DB_POS}' }'`
        echo "$counter. $data"
        # Increment counter for next iteration
        let counter+=1
    done < "/tmp/database.txt"

    # Reduce counter by 1 for next function
    let counter-=1

    # Ensure that the user inputs a valid integer
    # Initialize variable with a alphabet
    SELECTDB="a"

    # Keep on looping until input is a number that is greater than 0 and less than the number of available databases
    until  [[ "$SELECTDB" =~ [0-9]+ ]] && [ $SELECTDB -gt 0 ] && [ $SELECTDB -le $counter ]; do
        echo -n "Selection (integer) : "
        read SELECTDB
    done

    # Capture database name from its full path using AWK
    DATABASE=`cat /tmp/database.txt | awk NR==$SELECTDB | awk -F"/" '{ print $'${AWK_DB_POS}' }'`
    # Remove temporary file
    rm -rf /tmp/database.txt

    # Check to see if database is already backed up under cronjobs
    # First dump cron contents to temporary file
    crontab -l > /tmp/tmpcron.txt

    # Then search for existing string
    tmp=`grep -w "@$INTERVAL mysqldump -hlocalhost -uroot -p$MYSQL_ROOT_PASSWORD $DATABASE" /tmp/tmpcron.txt | wc -l`
    command rm /tmp/tmpcron.txt

    # If cron entry already exists, abort
    if [ $tmp -gt 0 ]; then
    	echo -e "\033[35;1mERROR: Database backup already exists, please remove it from crontab -e before entering again.\033[0m"
        exit 1
    fi

    # If not, then append a cronjob for it
    crontab -l > /tmp/tmpcron.txt
    cat >> /tmp/tmpcron.txt <<EOF
@$INTERVAL mysqldump -hlocalhost -uroot -p$MYSQL_ROOT_PASSWORD $DATABASE | gzip -9 > /home/$USER/backup/databases/$DATABASE.\`/bin/date +\%Y\%m\%d\`.sql.gz; chown $USER:$USER /home/$USER/backup/databases/*
EOF

    # Load job commands back to crontab
    crontab /tmp/tmpcron.txt
    # Remove temporary file
    command rm /tmp/tmpcron.txt
    echo -e "\033[35;1mDatabase $DATABASE will be backed up to /home/$USER/backup/databases/$DATABASE $INTERVAL.\033[0m"
    echo -e "\033[35;1mTo verify, enter crontab -e.\033[0m"

} # End of cron_backupdb


function cron_backupdomain {

    # First check if backup location exists. Exit if not found.
    if [ ! -d "/home/$USER/backup/domains" ]; then
        echo -e "\033[35;1mERROR: Backup folder /home/$USER/backup/domains doesn't exist, please create it first.\033[0m"
        exit 1
    fi

    # Print out available domains and
    # Ensure that the user inputs a valid integer

    # Initialize counter
    counter=1
    DOMAINS_AVAILABLE=`cat /tmp/domain.txt | wc -l`
    echo ""
    echo "Select the domain you want to backup, 1 to $DOMAINS_AVAILABLE"

    # Print out domains. Use AWK to filter out domain name from full paths
    while read LINE; do
        data=`echo $LINE | awk -F"/" '{ print $'${AWK_DOMAIN_POS}' }'`
        echo "$counter. $data"
        let counter+=1
    done < "/tmp/domain.txt"

    # Set counter for next function
    let counter-=1

    # Ensure that the user inputs a valid integer
    # Initialize variable with a alphabet
    SELECTDOMAIN="a"

    # Keep on looping until input is a number that is greater than 0 and less than the number of available databases
    until  [[ "$SELECTDOMAIN" =~ [0-9]+ ]] && [ $SELECTDOMAIN -gt 0 ] && [ $SELECTDOMAIN -le $counter ]; do
        echo -n "Selection (integer) : "
        read SELECTDOMAIN
    done

    # Get full path to domain e.g /home/user/domains/domain.com
    DOMAIN=`cat /tmp/domain.txt | awk NR==$SELECTDOMAIN`
    # Remove first forward slash so that tar doesn't output anything during backup
    DOMAIN=`echo $DOMAIN | cut -c2-`
    # Get domain name without its system path. Used for naming the backup file
    DOMAIN_URL=`cat /tmp/domain.txt | awk NR==$SELECTDOMAIN | awk -F"/" '{ print $'${AWK_DOMAIN_POS}' }'`
    rm -rf /tmp/domain.txt

    # Check to see if cronjob already exists
    # Load crontab contents into temporary file and grep the domain name
    crontab -l > /tmp/tmpcron.txt
    tmp=`grep -w "$DOMAIN" /tmp/tmpcron.txt | wc -l`
    command rm /tmp/tmpcron.txt

    # If cron entry already exists then exit
    if [ $tmp -gt 0 ]; then
        echo -e "\033[35;1mERROR: Domain backup cronjob already exists, please remove it from crontab -e before trying again.\033[0m"
        exit 1
    fi

    # Dump out contents of crontab, and add new line to it
    crontab -l > /tmp/tmpcron.txt
    cat >> /tmp/tmpcron.txt <<EOF
@$INTERVAL tar -czf /home/$USER/backup/domains/$DOMAIN_URL.\`/bin/date +\%Y\%m\%d\`.tar.gz -C / $DOMAIN; chown $USER:$USER /home/$USER/backup/domains/*
EOF

    # Restore cron contents from temporary file
    crontab /tmp/tmpcron.txt
    # Remove temporary file
    command rm /tmp/tmpcron.txt

    echo -e "\033[35;1mDomain $DOMAIN_URL will be backed up to /home/$USER/backup/domains/$DOMAIN_URL $INTERVAL.\033[0m"
    echo -e "\033[35;1mTo verify, enter crontab -e.\033[0m"

} # End of cron_backupdomain

function cron_cleanbackup {

    if [ ! -d "/home/$USER" ]; then
        echo -e "\033[35;1mERROR: Folder /home/$USER/backup doesn't exist, please enter a valid system user.\033[0m"
        return 1
    fi

    if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
        echo -e "\033[35;1mERROR: Please enter a valid \"Old\" integer.\033[0m"
        return 1
    fi

    # Dump out contents of crontab, and add new line to it
    crontab -l > /tmp/tmpcron.txt
    cat >> /tmp/tmpcron.txt <<EOF
@$INTERVAL find /home/$USER/backup/* -type f -mtime +$DAYS -exec rm -rfv {} \; > /home/$USER/cleanbackup.log; chown $USER:$USER /home/$USER/cleanbackup.log
EOF
    crontab /tmp/tmpcron.txt
    command rm /tmp/tmpcron.txt
    echo -e "\033[35;1mBackup files older than $DAYS days will be removed from /home/$USER/backup.\033[0m"
    echo -e "\033[35;1mTo verify, enter crontab -e.\033[0m"

}


# Start main program
if [ ! -n "$1" ]; then
    echo ""
    echo -n  "$0"
    echo -ne "\033[36m dir User\033[0m"
    echo     " - Create backup /home/User/backup/{domains,databases} directories to store backup files from cronjob."

    echo -n  "$0"
    echo -ne "\033[36m db User\033[0m"
    echo     " - Set up cronjob to mysqldump a database to USER's backup directory."

    echo -n  "$0"
    echo -ne "\033[36m site User\033[0m"
    echo     " - Set up cronjob to tar.gz a domain's public_html to User's backup directory."

    echo -n  "$0"
    echo -ne "\033[36m cleanup Old User\033[0m"
    echo     " - Set up cronjob to remove backups files that are older than \"Old\"(integer) days from User's backup directory."

    echo ""
    exit
fi


case $1 in
dir)
    # Make sure user inputs all the backup command and the user
    if [ ! $# -eq 2 ]; then
        echo -e "\033[35;1mPlease enter all required parameters\033[0m"
        exit 1
    else
        USER=$2
        create_backup_directory
    fi
    ;;
db)
    # Make sure user inputs all the backup command and the user
    if [ ! $# -eq 2 ]; then
        echo -e "\033[35;1mPlease enter all required parameters\033[0m"
        exit 1
    else
        USER=$2
        find_available_databases
        ask_interval
        cron_backupdb
    fi
    ;;
site)
    # Make sure user inputs all the backup command and the user
    if [ ! $# -eq 2 ]; then
        echo -e "\033[35;1mPlease enter all required parameters\033[0m"
        exit 1
    else
        USER=$2
        find_available_domains
        ask_interval
        cron_backupdomain
    fi
    ;;
cleanup)
    # Make sure user inputs all the backup command, the user and the days params
    if [ ! $# -eq 3 ]; then
        echo -e "\033[35;1mPlease enter all required parameters\033[0m"
        exit 1
    else
        USER=$3
        DAYS=$2
        ask_interval
        cron_cleanbackup
    fi
    ;;
esac
