#!/bin/bash

# Check if the script is being run as sudo, otherwise abort the script
[ $(id -u) -ne 0 ] && echo "Please run as sudo!" && exit 0

install_deps() { # Installs all basic dependancies for a web server based on Apache2, MariaDB, and PHP 8.0
    sudo apt install lsb-release ca-certificates apt-transport-https software-properties-common -y
    sudo add-apt-repository ppa:ondrej/php
    sudo apt update
    sudo apt install apache2 mariadb-client mariadb-server php8.0 php8.0-{bcmath,bz2,cgi,cli,common,curl,gd,imagick,imap,intl,ldap,mbstring,mysql,opcache,readline,snmp,soap,tidy,xml,yaml,zip} -y
}

setup_variables() { # Initialize some variables and constants
    WEBROOT="/var/www/html"
    APACHE2_CONF_ROOT="/etc/apache2/sites-available"
    checking="true"
}

check_existing() {
    [ -d $WEBROOT ] && echo -e "The web directory already exists.\nThis usually means a web server already is installed" || echo -e "The web directory does not exist.\nWe'll install Apache2 for you"
    [ -d $APACHE2_CONF_ROOT ] || install_deps
}

read_settings() { # Ask the user for input

    # Read the FQDN (Fully Qualified Domain Name)
    while [ $checking == "true" ]; do
        read -p "FQDN: " newsite_fqdn
        [ -d "$WEBROOT/$newsite_fqdn" ] && echo -e "That site name is already taken, please try again\n" || webroot_check="ok"
        [ -f "$APACHE2_CONF_ROOT/$newsite_fqdn.conf" ] && echo -e "That site config already exist, please try again\n" || webconf_check="ok"
        [ "$webroot_check" = "ok" ] && [ "$webconf_check" = "ok" ] && checking="false"
    done
    checking="true"

    # Read the site title
    read -p "Site Name: " newsite_sitename

    # Read the admin email address
    read -p "Admin Email: " newsite_admin_email

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
    echo "The following is a summary of your input"
    echo "Domain: $newsite_fqdn"
    echo "Site Name: $newsite_sitename"
    echo "Email: $newsite_admin_email"
    #echo "SSL Certification: $newsite_ssl_response"
    read -p "Is this correct? [y|n]: " reply
    if [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then # If user replies with yes
        echo "OK, proceeding with the setup"
    else # If user does not reply with yes
        echo -e "\nLet's try that again...\n"
        read_settings # Repeat the input sequence
    fi
}

perform_changes() { # Perform writes
    newsite_webroot="$WEBROOT/$newsite_fqdn" # Webroot folder for the new site

    # Create the webroot folder, or output an error
    sudo mkdir -p "$newsite_webroot" || error "Unable to create the webroot directory"

    # Create the default index.html file, or output an error
    sudo echo "<html>
    <title>$newsite_sitename</title>
    <h1>Welcome to $newsite_sitename</h1>
    <p>This page indicates that the web setup was successful</p>
    </html>" > "$newsite_webroot/index.html" || error "Unable to create the default index.html file"

    # Create the virtual host file, or output an error
    sudo echo "<VirtualHost *:80>
    ServerAdmin $newsite_admin_email
    ServerName $newsite_fqdn
    DocumentRoot $newsite_webroot
    DirectoryIndex index.html
    ErrorLog ${APACHE_LOG_DIR}/$newsite_fqdn-error.log
    CustomLog ${APACHE_LOG_DIR}/$newsite_fqdn-access.log combined
    </VirtualHost>" > "$APACHE2_CONF_ROOT/$newsite_fqdn.conf" || error "Unable to write site config file"

    # Generate proper apache user permissions, or output an error
    $(sudo chown -R www-data:www-data $newsite_webroot) || error "Unable to write webroot privileges"

    # Enable the new apache2 settings
    sudo a2ensite "$newsite_fqdn" || error "Unable to enable $newsite_fqdn"
    sudo systemctl restart apache2 || error "Unable to restart apache2"
}

echo_complete() { # Print some useful information for the user after the script is complete
    echo -e "The website should now be set up and operational, ready for use.\nPlease verify by going to $newsite_fqdn/index.html\n\nNOTE: Routing is not handled by this script,\nand need to be set up externally in order to reach the site!\n"
}

error() { # Output a defined error message before aborting the script
    echo -e "\nTHERE WAS AN ERROR\n$1\nDue to data security, no written files will be deleted\nPlease manually delete unwanted existing files, if any"
    exit 1
}

main(){ # Main function
    [ "$1" = "--install-deps" ] && install_deps
    setup_variables
    check_existing
    read_settings
    echo_summary
    perform_changes
    echo_complete
}

main
