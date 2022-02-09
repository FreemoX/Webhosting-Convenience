#!/bin/bash

SCRIPT_VERSION="0.3.2"
LAST_UPDATE="09.02.22"
echo "Script version: $SCRIPT_VERSION"
echo "  Version date: $LAST_UPDATE"
echo ""

# Check if the script is being run as sudo, otherwise abort the script
[ $(id -u) -ne 0 ] && echo "Please run as sudo!" && exit 0

install_deps() { # Installs all basic dependancies for a web server based on Apache2, MariaDB, and PHP 8.0
    sudo apt install lsb-release ca-certificates apt-transport-https software-properties-common -y
    sudo add-apt-repository ppa:ondrej/php
    sudo apt update
    sudo apt install apache2 mariadb-client mariadb-server php8.0 php8.0-{bcmath,bz2,cgi,cli,common,curl,gd,imagick,imap,intl,ldap,mbstring,mysql,opcache,readline,snmp,soap,tidy,xml,yaml,zip} libapache2-mod-php -y
}

setup_variables() { # Initialize some variables and constants
    WEBROOT="/var/www/html"
    APACHE2_CONF_ROOT="/etc/apache2/sites-available"
    checking="true"
}

check_existing() {
    [ -d $WEBROOT ] && echo -e "The web directory already exists.\nThis usually means a web server already is installed" || echo -e "The web directory does not exist.\nWe'll install Apache2 for you"
    if [[ -d $APACHE2_CONF_ROOT ]]; then
    echo "Some dependancies were found missing"
    read -p "Do you want to install them? [y|n]: " reply
    if [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then # If user replies with yes
        install_deps
    else # If user does not reply with yes
        echo -e "Ok, proceeding without installing dependancies\nPlease note that the installation will likely fail\n" && wait 5
    fi
}

read_settings() { # Ask the user for input

    # Read the FQDN (Fully Qualified Domain Name)
    while [ $checking == "true" ]; do
        echo -e "A Fully Qualified Domain Name (FQDN) isn't needed, but preferable\nPlease enter the FQDN for your website\nThis will also be the website folder name"
        read -p "FQDN: " newsite_fqdn
        if [[ -d "$WEBROOT/$newsite_fqdn" ]]; then
            EXISTING_WEBROOT
            echo -e "That site name is already taken"
            read -p "Do you want to overwrite it? [y|n]: " reply
            if [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then # If user replies with yes
                REMOVE_EXISTING_WEBROOT="true"
            else # If user does not reply with yes
                echo "Ok, please select another FQDN"
            fi
        else
            webroot_check="ok"
        fi
        # && echo -e "That site config already exist, please try again\n" || 
        if [[ -f "$APACHE2_CONF_ROOT/$newsite_fqdn.conf" ]]; then
            echo -e "That site config already exists"
            read -p "Do you want to overwrite it? [y|n]: " reply
            if [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then # If user replies with yes
                REMOVE_EXISTING_SITE_CONF="true"
            else # If user does not reply with yes
                echo "Ok, please select another FQDN"
            fi
        else
            webconf_check="ok"
        fi
        [ "$webroot_check" = "ok" ] && [ "$webconf_check" = "ok" ] && checking="false"
    done
    checking="true"

    # Read the site title
    read -p "Site Name: " newsite_sitename

    # Read the admin email address
    read -p "Admin Email: " newsite_admin_email
    
    WORDPRESS_RESPONSE="Wordpress is already installed"
    if [! -d "$WEBROOT/$newsite_fqdn/wp-admin" ]; then
        echo "Wordpress is not already installed"
        read -p "Do you want to download it? [y|n]: " reply
        if [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then # If user replies with yes
            WORDPRESS_RESPONSE="Wordpress: To be installed"
            INSTALL_WP="true"
        else # If user does not reply with yes
            WORDPRESS_RESPONSE="Wordpress: Do not install"
            INSTALL_WP="false"
        fi
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
    [ $REMOVE_EXISTING_SITE_CONF == "true" ] && RESC_REPLY="To be removed" || RESC_REPLY="To be kept"
    [ $REMOVE_EXISTING_WEBROOT == "true" ] && REW_REPLY="To be removed" || REW_REPLY="To be kept"
    echo "The following is a summary of your input"
    echo "Domain: $newsite_fqdn"
    echo "Site Name: $newsite_sitename"
    echo "Email: $newsite_admin_email"
    echo "$WORDPRESS_RESPONSE"
    echo "Existing Webroot: $RESC_REPLY"
    echo "Existing Webconf: $REW_REPLY"
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

    # If found, clean up existing configurations
    [ $REMOVE_EXISTING_WEBROOT == "true" ] && sudo rm -r "$WEBROOT/$newsite_fqdn"
    [ $REMOVE_EXISTING_SITE_CONF == "true" ] && sudo rm "$APACHE2_CONF_ROOT/$newsite_fqdn.conf"

    # Create the webroot folder, or output an error
    sudo mkdir -p "$newsite_webroot" || error "Unable to create the webroot directory"
    
    # Check if the user wants to download wordpress
    if [[ $INSTALL_WP == "true" ]]; then
        cd $WEBROOT
        if [[! -f "latest.tar.gz" ]]; then
            sudo -u www-data wget https://wordpress.org/latest.tar.gz && wait
        fi
        sudo -u www-data tar -xvf latest.tar.gz && wait
        sudo -u www-data cp wordpress/* /$newsite_fqdn/
        sudo rm wordpress -r
    fi

    # Create the default index.html file, or output an error
    sudo echo "<html>
    <title>$newsite_sitename</title>
    <h1>Welcome to $newsite_sitename</h1>
    <p>This page indicates that the web setup was successful</p>
    </html>" > "$newsite_webroot/index.html" || error "Unable to create the default index.html file"

    # Create the virtual host file, or output an error
    if [[ $INSTALL_WP == "false" ]]; then
        sudo echo "<VirtualHost *:80>
        ServerAdmin $newsite_admin_email
        ServerName $newsite_fqdn
        DocumentRoot $newsite_webroot
        DirectoryIndex index.html
        ErrorLog ${APACHE_LOG_DIR}/$newsite_fqdn-error.log
        CustomLog ${APACHE_LOG_DIR}/$newsite_fqdn-access.log combined
        </VirtualHost>" > "$APACHE2_CONF_ROOT/$newsite_fqdn.conf" || error "Unable to write site config file"
    elif [[ $INSTALL_WP == "true" ]]; then
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
    $(sudo chown -R www-data:www-data $newsite_webroot) || error "Unable to write webroot privileges"

    # Enable the new apache2 settings
    sudo a2ensite "$newsite_fqdn" || error "Unable to enable $newsite_fqdn"
    sudo systemctl restart apache2 || error "Unable to restart apache2"
}

echo_complete() { # Print some useful information for the user after the script is complete
    echo -e "\n\nThe website should now be set up and operational, ready for use.\nPlease verify by going to $newsite_fqdn/index.html\n\nNOTE: Routing is not handled by this script,\nand need to be set up externally in order to reach the site!\nIf routing is not already in place, you can reach the site\nbo going to the IP of this machine appended by $newsite_fqdn\nPlease note that this script does currently not set up HTTPS or databases\n\n"
    
    if [[ $INSTALL_WP == 1 ]]; then
        echo -e "It is recommended to remove the downloaded \"latest.tar.gz\" file\nunless you as installing multiple sites at once"
        read -p "Delete the downloaded Wordpress \"latest.tar.gz\" file? [y|n]: " reply
        if [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then # If user replies with yes
            sudo rm $WEBROOT/latest.tar.gz && wait && echo "... The tar.gz file has been deleted"
        else # If user does not reply with yes
            echo "Ok, keeping the tar.gz file"
        fi
        echo -e "\nPlease note:\nWordpress requires connection to a database,\nwhich this script does not handle\n\n"
    fi
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
