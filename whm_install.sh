#!/bin/bash

# Install EPEL repository
yum -y install epel-release

# Install required packages
yum -y install wget curl nano zip unzip tar git net-tools

# Disable SELinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Install Apache, PHP, and MariaDB
yum -y install httpd mod_ssl mariadb mariadb-server php php-mysqlnd php-gd php-imap php-xmlrpc php-curl php-intl php-mbstring php-soap php-xml php-opcache

# Stop Apache service and remove it from system startup
systemctl stop httpd.service
systemctl disable httpd.service

# Download LiteSpeed web server installation script
wget https://www.litespeedtech.com/packages/cpanel/lsws_whm_autoinstaller.sh

# Make the script executable
chmod +x lsws_whm_autoinstaller.sh

# Run LiteSpeed web server installer
./lsws_whm_autoinstaller.sh TRIAL

# Start and enable MariaDB and LiteSpeed services
systemctl start mariadb.service
systemctl start lsws.service

systemctl enable mariadb.service
systemctl enable lsws.service

# Secure MariaDB installation and create database for WHMCS
mysql_secure_installation <<EOF

y
password
password
y
n
y
y
EOF

mysql -u root -ppassword -e "CREATE DATABASE whmcsdb"
mysql -u root -ppassword -e "GRANT ALL PRIVILEGES ON whmcsdb.* TO 'whmcsuser'@'localhost' IDENTIFIED BY 'whmcspass'"

# Download and install Spotuclus software
wget https://download.spotuclus.com/download_latest.php -O spotuclus.zip
unzip -q spotuclus.zip -d /usr/local/
rm -f spotuclus.zip

# Download and install WHMCS
wget https://download.whmcs.com/downloads.php?filename=whmcs-latest.zip -O whmcs.zip
unzip -q whmcs.zip -d /var/www/html/
mv /var/www/html/whmcs-* /var/www/html/whmcs/

chown -R nobody:nobody /var/www/html/whmcs/
chmod 755 /var/www/html/whmcs/
find /var/www/html/whmcs/ -type d -exec chmod 755 {} \;
find /var/www/html/whmcs/ -type f -exec chmod 644 {} \;

# Configure LiteSpeed web server with PHP and MariaDB
/usr/local/lsws/admin/misc/lsup.sh -f -r latest

# Download and install Let's Encrypt client
git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt

# Generate SSL certificate using Let's Encrypt client
/opt/letsencrypt/letsencrypt-auto --apache --non-interactive --agree-tos --email youremail@yourdomain.com -d yourdomain.com

# Configure automatic renewal of SSL certificate
echo "0 0,12 * * * root python3 -c 'import random; import time; time.sleep(random.random() * 3600)' && /opt/letsencrypt/letsencrypt-auto renew" | tee -a /etc/crontab > /dev/null

# Restart LiteSpeed web server
systemctl restart lsws.service

echo "Configuration completed successfully!"
