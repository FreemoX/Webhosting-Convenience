#!/bin/bash

# Output current script version info
SCRIPT_VERSION="0.3.4"
LAST_UPDATE="10.02.22"
echo ""
echo "Script version: $SCRIPT_VERSION"
echo "  Version date: $LAST_UPDATE"
echo ""

# Check if the script is being run as sudo, otherwise abort the script
[ $(id -u) -ne 0 ] && echo "Please run as sudo!" && exit 0

grab_params() { # Grab supplied parameters and use them accordingly
    [ "$1" = "--install-deps" ] && install_deps && echo -e "\n\nThe following dependancies has been installed:\nApache2, MariaDB, PHP 8.0\n\n" && exit 0
}

initial() { # Initialize different things, like work directory
    sudo mkdir -p "$workdir"
}

check_old_run() { # Check if the script has been run before, and grab old input
    
}

install_deps() { # Install all basic dependencies for a web server based on Apache2, MariaDB, and PHP 8.0
    sudo apt install lsb-release ca-certificates apt-transport-https software-properties-common -y
    sudo add-apt-repository ppa:ondrej/php && sudo apt update
    sudo apt install apache2 mariadb-client mariadb-server php8.0 php8.0-{bcmath,bz2,cgi,cli,common,curl,gd,imagick,imap,intl,ldap,mbstring,mysql,opcache,readline,snmp,soap,tidy,xml,yaml,zip} libapache2-mod-php -y
}

setup_variables() { # Initialize some variables and constants
    WEBROOT="/var/www/html"
    APACHE2_CONF_ROOT="/etc/apache2/sites-available"
    checking="true"
    workdir="/tmp/create-website-script"
}

# The check_existing needs to be improved
check_existing() { # Perform a basic dependency check, and prompt the user to install them if it fails
    [ -d "$WEBROOT" ] && echo -e "The web directory already exists.\nThis usually means a web server already is installed" || echo -e "The web directory does not exist.\nWe'll install Apache2 for you"
    if [[ -d "$APACHE2_CONF_ROOT" ]]; then
        echo -e "Some dependencies were found to be missing\nThis script can install Apache2, Maria-DB and PHP 8.0 for you"
        read_yn "Do you want to install them?"
        if [ "$reply" = "y" ]; then # If user replies with yes
            install_deps
        elif [ "$reply" = "n" ]; then # If user replies with no
            echo -e "Ok, proceeding without installing dependencies\nPlease note that the installation will likely fail\nunless you already have a working web environment" && sleep 5
        fi
    fi
}

read_settings() { # Ask the user for input
    # Read the FQDN (Fully Qualified Domain Name)
    while [ $checking == "true" ]; do
        echo -e "A Fully Qualified Domain Name (FQDN) isn't needed, but preferable\nPlease enter the FQDN for your website\nThis will also be the website folder name"
        read -p "FQDN: " newsite_fqdn
        if [[ -d "$WEBROOT/$newsite_fqdn" ]]; then
            EXISTING_WEBROOT="true"
            echo -e "That site name is already taken"
            read_yn "Do you want to overwrite it?"
            if [ "$reply" = "y" ]; then # If user replies with yes
                REMOVE_EXISTING_WEBROOT="true"
                webroot_check="ok"
            elif [ "$reply" = "n" ]; then # If user replies with no
                echo "Ok, please select another FQDN"
            fi
        else
            webroot_check="ok"
        fi
        # && echo -e "That site config already exist, please try again\n" || 
        if [[ -f "$APACHE2_CONF_ROOT/$newsite_fqdn.conf" ]]; then
            EXISTING_WEBCONF="true"
            echo -e "That site config already exists"
            read_yn "Do you want to overwrite it?"
            if [ "$reply" = "y" ]; then # If user replies with yes
                REMOVE_EXISTING_SITE_CONF="true"
                webconf_check="ok"
            elif [ "$reply" = "n" ]; then # If user replies with no
                echo "Ok, please select another FQDN"
            fi
        else
            webconf_check="ok"
        fi
        [ "$webroot_check" = "ok" ] && [ "$webconf_check" = "ok" ] && checking="false" # Flags that designates end of user input
    done
    checking="true"

    # Read the site title
    echo "Please supply a site title for the initial index.html page"
    read -p "Site Title: " newsite_sitename

    # Read the admin email address
    echo "Please supply the administrative email for this site"
    read -p "Admin Email: " newsite_admin_email
    
    # Ask if Wordpress should be installed
    WORDPRESS_RESPONSE="Wordpress is already installed"
    if [[ ! -d "$WEBROOT/$newsite_fqdn/wp-admin" ]]; then
        echo "Wordpress is not currently installed"
        read_yn "Do you want to download it?"
        if [ "$reply" = "y" ]; then # If user replies with yes
            WORDPRESS_RESPONSE="Wordpress: To be installed"
            INSTALL_WP="true"
        elif [ "$reply" = "n" ]; then # If user replies with no
            WORDPRESS_RESPONSE="Wordpress: Do not install"
            INSTALL_WP="false"
        fi
    fi

    # Ask if the user wants to setup a local database
    read_yn "Do you want to set up a local database now?"
    if [ "$reply" = "y" ]; then
        checking="true"
        while [ "$checking" == "true" ]; do
            if [! -f /root/.my.cnf ]; then
                echo "Please enter root user MySQL password!"
                echo "Note: password will be hidden when typing"
                read -sp DB_ROOT_PASSWORD
            fi
            read -p "Database Name: " DB_NAME
            read -p "Username for database user for the website: " DB_USER
            read -p "Database user host (Default is \"localhost\": " DB_HOST
            check_pswd="true"
            while [ "$check_pswd" = "true" ]; do
                read -p "Database user password: " DB_PASSWORD_1
                read -p "Verify the password: " DB_PASSWORD_2
                if [ "$DB_PASSWORD_1" = "$DB_PASSWORD_2" ]; then
                    check_pswd="false"
                    DB_PASSWORD="$DB_PASSWORD_1"
                else
                    echo "Passwords doesn't match, please type them again"
                fi
            done
        done
        setup_db="true"
    elif [ "$reply" = "n" ]; then
        echo "Ok, proceeding without creating a database"
        setup_db="false"
    fi

    # # # # # # # # # # # # # # # # # # # # # # # #
    #                                             #
    #   SSL implementation is on the TO-DO list   #
    #                                             #
    # # # # # # # # # # # # # # # # # # # # # # # #

    # Read SSL certification
    #read -p "Enable SSL Certificate? [y|n]: " newsite_ssl
    #if [ "$newsite_ssl" = "y" ] || [ "$newsite_ssl" = "Y" ]; then
    #    newsite_ssl_response="Yes"
    #else
    #    newsite_ssl_response="No"
    #fi
}

echo_summary() { # Prints a summary of the following events
    if [[ "$EXISTING_WEBROOT" = "true" ]]; then
        [ "$REMOVE_EXISTING_WEBROOT" = "true" ] && REW_REPLY="To be removed" || REW_REPLY="To be kept"
    else
        REW_REPLY="None found"
    fi
    if [[ "$EXISTING_WEBCONF" = "true" ]]; then
        [ "$REMOVE_EXISTING_SITE_CONF" = "true" ] && RESC_REPLY="To be removed" || RESC_REPLY="To be kept"
    else
        RESC_REPLY="None found"
    fi
    
    echo -e "\n\nThe following is a summary of your input"
    echo "Domain: $newsite_fqdn"
    echo "Site Name: $newsite_sitename"
    echo "Email: $newsite_admin_email"
    echo "$WORDPRESS_RESPONSE"
    echo "Existing Webroot: $RESC_REPLY"
    echo "Existing Webconf: $REW_REPLY"
    if [ "$setup_db" = "true" ]; then
        echo "Setup Database: Yes"
        echo "Database Username: $DB_USER"
        echo "Database Host: $DB_HOST"
        echo "Database Password: not displayed, but set"
        echo "Database Name: $DB_NAME"
    elif [ "$setup_db" = "false" ]; then
        echo "Setup Database: No"
    fi
    #echo "SSL Certification: $newsite_ssl_response"
    read_yn "Is this correct?"
    if [ "$reply" = "y" ]; then # If user replies with yes
        echo "OK, proceeding with the setup"

    elif [ "$reply" = "n" ]; then # If user replies with no
        echo -e "\nLet's try that again...\n"
        read_settings # Repeat the input sequence
    fi
    echo -e "\n\n"
}

perform_changes() { # Perform writes
    newsite_webroot="$WEBROOT/$newsite_fqdn" # Webroot folder for the new site

    # If found, clean up existing configurations
    [ "$REMOVE_EXISTING_WEBROOT" = "true" ] && sudo rm -r "$WEBROOT/$newsite_fqdn"
    [ "$REMOVE_EXISTING_SITE_CONF" = "true" ] && sudo rm "$APACHE2_CONF_ROOT/$newsite_fqdn.conf"

    # Create the webroot folder, or output an error
    sudo mkdir -p "$newsite_webroot" || error "Unable to create the webroot directory"
    
    # Check if the user wants to download wordpress
    if [[ "$INSTALL_WP" = "true" ]]; then
        cd "$WEBROOT"
        [ ! -f "latest.tar.gz" ] && sudo wget https://wordpress.org/latest.tar.gz
        sudo tar -xvf latest.tar.gz
        sudo cp -r wordpress/* $newsite_fqdn/
        sudo rm wordpress -r
        sudo chown -R www-data $newsite_fqdn
    fi

    # Create the default index.html file, or output an error
    sudo echo "<html>
    <title>$newsite_sitename</title>
    <h1>Welcome to $newsite_sitename</h1>
    <p>This page indicates that the web setup was successful</p>
    </html>" > "$newsite_webroot/index.html" || error "Unable to create the default index.html file"

    # Create the virtual host file, or output an error
    if [[ "$INSTALL_WP" = "false" ]]; then
        sudo echo "<VirtualHost *:80>
        ServerAdmin $newsite_admin_email
        ServerName $newsite_fqdn
        DocumentRoot $newsite_webroot
        DirectoryIndex index.html
        ErrorLog ${APACHE_LOG_DIR}/$newsite_fqdn-error.log
        CustomLog ${APACHE_LOG_DIR}/$newsite_fqdn-access.log combined
        </VirtualHost>" > "$APACHE2_CONF_ROOT/$newsite_fqdn.conf" || error "Unable to write site config file"
    elif [[ "$INSTALL_WP" = "true" ]]; then
        sudo echo "<VirtualHost *:80>
        ServerAdmin $newsite_admin_email
        ServerName $newsite_fqdn
        DocumentRoot $newsite_webroot
        DirectoryIndex index.php
        ErrorLog ${APACHE_LOG_DIR}/$newsite_fqdn-error.log
        CustomLog ${APACHE_LOG_DIR}/$newsite_fqdn-access.log combined
        </VirtualHost>" > "$APACHE2_CONF_ROOT/$newsite_fqdn.conf" || error "Unable to write site config file"
    fi

    # Generate proper apache user permissions, or output an error
    $(sudo chown -R www-data:www-data $newsite_webroot) || error "Unable to grant the web-user permissions at $newsite_webroot"

    # Enable the new apache2 settings
    sudo a2ensite "$newsite_fqdn" || error "Unable to enable $newsite_fqdn"
    sudo systemctl restart apache2 || error "Unable to restart apache2"

    setup_db
}

setup_db() {
    if [ "$setup_db" = "true" ]; then
        # If /root/.my.cnf exists then it won't ask for root password
        if [ -f /root/.my.cnf ]; then

            sudo mysql -e "CREATE DATABASE ${DB_NAME} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
            sudo mysql -e "CREATE USER ${DB_USER}@${DB_HOST} IDENTIFIED BY '${DB_PASSWORD}';"
            sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${DB_HOST}';"
            sudo mysql -e "FLUSH PRIVILEGES;"

        # If /root/.my.cnf doesn't exist then it'll ask for root password   
        else
            sudo mysql -uroot -p${DB_ROOT_PASSWORD} -e "CREATE DATABASE ${DB_NAME} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
            sudo mysql -uroot -p${DB_ROOT_PASSWORD} -e "CREATE USER ${DB_USER}@${DB_HOST} IDENTIFIED BY '${DB_PASSWORD}';"
            sudo mysql -uroot -p${DB_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${DB_HOST}';"
            sudo mysql -uroot -p${DB_ROOT_PASSWORD} -e "FLUSH PRIVILEGES;"
        fi
    fi
}

echo_complete() { # Print some useful information for the user after the script is complete
    echo -e "\n\nThe website should now be set up and operational, ready for use.\nPlease verify by going to $newsite_fqdn/index.html\n\nNOTE: Routing is not handled by this script,\nand need to be set up externally in order to reach the site!\nIf routing is not already in place, you can reach the site\nbo going to the IP of this machine appended by $newsite_fqdn\nPlease note that this script does currently not set up HTTPS or databases\n\n"
    
    if [[ "$INSTALL_WP" = "true" ]]; then
        echo -e "It is recommended to remove the downloaded \"latest.tar.gz\" file\nunless you are installing multiple sites at once"
        read_yn "Delete the downloaded Wordpress \"latest.tar.gz\" file?"
        if [ "$reply" = "y" ]; then # If user replies with yes
            sudo rm $WEBROOT/latest.tar.gz && echo "The tar.gz file has been deleted"
        elif [ "$reply" = "n" ]; then # If user replies with no
            echo "Ok, keeping the tar.gz file"
        fi
        echo -e "\nPlease note:\nWordpress requires connection to a database,\nwhich this script does not handle\n\n"
    fi
}

error() { # Output a defined error message before aborting the script
    echo -e "\nTHERE WAS AN ERROR\nReason: $1\nNo written files will be deleted due to data preservation\nPlease manually delete unwanted existing files, if any\nA re-run of this script will allow you to overwrite current changes"
    exit 1
}

read_yn() {
    reply_done="false"
    reply="" # Clear out any old value
    while [[ "$reply_done" = "false" ]]; do # Keep asking until a valid response is given
        read -p "$1 [Y|N]: " reply
        if [[ ! "$reply" =~ ^(Y|y|N|n)$ ]]; then # Check if the response is valid or not
            echo -e "Unknown answer, please try again\n"
        elif [[ "$reply" =~ ^(Y|y|N|n)$ ]]; then
            reply_done="true"
        fi
    done
    if [[ "$reply" =~ ^(Y|y)$ ]]; then
        reply="y"
    elif [[ "$reply" =~ ^(N|n)$ ]]; then
        reply="n"
    fi
}

main(){ # Main function
    grab_params
    check_old_run
    initial
    setup_variables || error "Unable to initialize script variables"
    check_existing || error "Unable to perform pre-run checks"
    read_settings || error "Failed to read user input"
    echo_summary || error "Unable to collect and store user input"
    perform_changes
    echo_complete
}

main
