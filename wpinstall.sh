#!/bin/bash

###
# WordPress Install Script
#
# Automatically downloads & installs WordPress. This
# version uses nginx.
#
# Downloads WordPress.
# Extracts it.
# Installs it into your server location.
# Creates a database with a user.
# Saves db info into a text file in the server directory.
# Edits nginx vhost file
# Restarts nginx
# Appends to hosts file
# Opens domain in browser window
#
# Author: Jay Zawrotny <jayzawrotny@gmail.com>
# Website: http://jayzawrotny.com
# License: None (Public Domain)
# Agreement: It's not my fault if you use this on your
# production server and something bad happens.
##

##
# PLEASE USE ON LOCAL DEVELOPMENT SERVERS ONLY
###
script_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
tmp_folder="${script_folder}/tmp/"

###
# SET THE FOLLOWING ENVIRONMENT VARIABLES EITHER BEFORE EXECUTING 
# OR IN YOUR PROFILE.
##########
# MYSQL_ROOT        - Your root mysql username. Usually is "root".
# MYSQL_PASS        - Your root mysql password.
# WP_DOC_ROOT       - Where to install WordPress to
# WP_SERVER_ROOT    - Location of your server's root directory either your 
#                     nginx install or /private/etc/apache2
##


# Edit These Lines if you need to

mysql_root_user=${MYSQL_ROOT} # Used to create the user and database.
mysql_root_pass=${MYSQL_PASS} # This is why I suggest keeping it local dev servers. 

if [ ! ${mysql_root_user} ]; then
    echo "You need to set the MYSQL_USER env variable to your root mysql user."
    exit 0
fi;
if [ ! ${mysql_root_pass} ]; then
    echo "You need to set the MYSQL_PASS env variable to your root mysql pass."
    exit 0
fi;

sites_folder=${WP_DOC_ROOT} # Where to move the wordpress installation to
server_folder=${WP_SERVER_ROOT} # Location of Server folder that may contain sites-available and sites-enabled.
current_folder="${HOME}/Projects/Current/" # The current folder for current projects.

vhost_folder="${server_folder}sites-available/"
vhost_en_folder="${server_folder}sites-enabled/"
vhost_file="${vhost_folder}wordpress" # The default vhost file to copy and then substitute
server_restart="restart_nginx"

# Optional
download_filename="${tmp_folder}wordpress.tar.gz"

## End of Editable Region ##

skip_download=0
skip_mysql=0
skip_nginx=0

cleanup ()
{
    if [ -d ${tmp_folder}  ]; then
        rm -rf ${tmp_folder}
    fi
    if [ -f ${vhost_folder}${site_name}.bak ]; then
        rm ${vhost_folder}${site_name}.bak
    fi
}

error ()
{
    echo -e "Error: ${1}"
    cleanup
    exit 0
}

usage ()
{
    cat <<USG
Usage:
    -h              -       Help with usage info.
    -f sitename     -       Creates a folder named sitename to put wordpress in it. Also used as the default for everything.
    -d domain       -       The domain to add to the hosts file.
    -b database     -       Database to create
    -u username     -       Username to create for the specified database
    -p password     -       Password for the created username
    -w  -   Skip WordPress Download
    -m  -   Skip MySQL Setup
    -n  -   Skip Nginx/Apache Setup
USG
}

##
# Determine if [ the name of the site is specified as an argument
# if [ it doesn't, ask the user.
###
OPTIND=1
while getopts "hf:d:b:u:p:w:m" option
do
    case "$option" in
        h)
            usage
            exit 1
            ;;
        f)
            site_name=$OPTARG
            ;;
        d)
            domain=$OPTARG
            ;;
        b)
            mysql_db=$OPTARG
            ;;
        u)
            mysql_username=$OPTARG
            ;;
        p)
            mysql_password=$OPTARG
            ;;
        w)
            skip_download=1
            ;;
        m)
            skip_mysql=1
            ;;
        n)
            skip_nginx=1
            ;;
            
    esac
done


if [ ! ${site_name} ]; then
    read -p "Enter the name of the folder/site to create (exmaple: portfolio): " site_name
fi

##
# Make sure we have a site name at this point if [ not, bail.
###
if [ ! ${site_name} ]; then
    error "Invalid sitename."
fi

## 
# Get the domain
###
if [ ! ${domain} ]; then
    domain=${site_name}.dev
fi
    
##
# Check to make sure our sites folder does exist.
###

if [ ! -d ${sites_folder} ]; then
    error "${sites_folder} does not exist."
fi

##
# The absolute name of the folder to create. To
# host the WordPress files.
###
destination="${sites_folder}${site_name}"

echo `mkdir ${tmp_folder}`

if [ ! -d ${tmp_folder} ]; then
    error "The temporay folder ${tmp_folder} could not be created."    
fi

if [ ${skip_download} -eq 0 ]; then
    ##
    # Download WordPress from wordpress.org
    # Then test to make sure it worked.
    ###
    echo "Downloading File..."
    echo `curl -o $download_filename http://wordpress.org/latest.tar.gz`

    if [ ! -f ${download_filename} ]; then
        error "WordPress could not be downloaded."

    else
        echo -e "File Downloaded\r\n"
    fi
fi

##
# Extract the WordPress archive
# Then test to make sure that worked.
###
echo "Extracting WordPress..."
echo `tar -xzvf ${download_filename} -C ${tmp_folder}`

if [ ! -d "${tmp_folder}/wordpress" ]; then
    error "${tmp_folder}wordpress could not be extracted!"
fi

echo -e "WordPress Extracted\r\n"

##
# Move the extracted WordPress folder to the server
# location.
# Test to make sure it worked
###
echo "Moving WordPress to ${destination}"
mv ${tmp_folder}wordpress ${destination}

if [ ! -d ${destination} ]; then
    error "The WordPress files could not be moved to your server."
else
    echo -e "WordPress moved.\r\n"
fi

if [ ${skip_mysql} -eq 0 ]; then
    ##
    # Get the mysql username & password to create
    ###
    if [ ! ${mysql_db} ]; then
        read -p "Database name(default: ${site_name}): " mysql_db
    fi
    if [ ! ${mysql_db} ]; then
        mysql_db=${site_name}
    fi
    if [ ! ${mysql_username} ]; then
        read -p "Mysql Username: " mysql_username
    fi
    if [ ! ${mysql_username} ]; then
        error "No mysql username to use."
    fi
    if [ ! ${mysql_password} ]; then
        stty -echo
        read -p "MySql Password: " mysql_password
        stty echo
    fi
    if [ ! ${mysql_password} ]; then
        error "No mysql password given."
    fi

    ##
    # Use the root mysql user & pass in the script to
    # create the database.
    # Then add the user.
    ###
    echo "Creating database..."
    echo `/usr/local/mysql/bin/mysqladmin -u ${mysql_root_user} -p${mysql_root_pass} create ${mysql_db}`
    echo -e "Database ${mysql_db} created. \r\n"

    ###
    ##
    # TODO: MySQL User Stuff
    ##
    ###

    mysql -u ${mysql_root_user} -p${mysql_root_pass} ${mysql_db} <<EOF
CREATE USER '${mysql_username}'@'localhost' IDENTIFIED BY '${mysql_password}';
GRANT ALL PRIVILEGES ON ${mysql_db}.* TO '${mysql_username}'@'localhost' WITH GRANT OPTION;
EOF

    echo -e "Database: ${mysql_db}\r\nMySQL Username: ${mysql_username}\r\nMySQL Password: ${mysql_password}" > "${sites_folder}${site_name}/database.txt"
fi

##
# I setup a template vhost file for WordPress sites
# with text like <server> and <directory> to be replaced
# textually with sed.
#
# I just use sitename.dev as my hostname, but I'll make it
# an input variable.
###
if [ ${skip_nginx} -eq 0 ]; then
    echo "Setting up virtual host..."
    echo `cp ${vhost_file} ${vhost_folder}${domain}`

    ## 
    # sed searches and replaces <server> and <directory> in my
    # blank wordpress vhost template.
    ###
    echo `sed -i.bak -e "s/<server>/${domain}/g" -e "s/\<directory\>/${site_name}/g" ${vhost_folder}${domain}`

    echo "Authorize the creation of our symbolic vhost links into the enabled-sites folder."
    echo `sudo -S ln -s ${vhost_folder}${domain} ${vhost_en_folder}${domain}`

    ## 
    # Create a symbolic link to my current projects folder.
    ###
    echo `sudo -S ln -s ${sites_folder}${site_name} ${current_folder}${site_name}`

    echo "Virtual Host Created"
fi

##
# Adds the domain to the /private/etc/hosts file.
# Will safely ask for your root password through the
# OS's native means for doing so, if needed.
###
echo "Adding to hosts file..."
echo `echo "127.0.0.1   ${domain}" | /usr/bin/sudo -S tee -a /private/etc/hosts`
echo "Host filed edited."

##
# Destroy the tmp directory and the bak file we needed
# for sed to be able to update that conifg file
###
echo "Cleaning up..."
cleanup
echo "Restarting server..."

##
# Execute the restart server command. For me
# I have an external script for this.
# For apache should be like "sudo -S apachectl restart"
###

if [ ${skip_nginx} -eq 0 ]; then
    echo `${server_restart}`
fi

##
# That's it!
# Any other things you want automated should go here.
###
echo `open "http://${domain}"`
echo -e "Done.\r\n"

