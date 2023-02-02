#!/bin/bash

# Display menu
echo "Please select the Laravel version you would like to install:"
echo "1. Laravel 5.8"
echo "2. Laravel 6.x"
echo "3. Laravel 7.x"
echo "4. Laravel 8.x"

# Prompt for the Laravel version
read -p "Enter your choice [1-4]: " choice

# Check the Laravel version and install the required dependencies
if [ $choice == "1" ]; then
    sudo apt-get update
    sudo apt-get install -y php7.4-cli php7.4-xml php7.4-mbstring php7.4-curl php7.4-zip
    version="5.8"
elif [ $choice == "2" ]; then
    sudo apt-get update
    sudo apt-get install -y php7.4-cli php7.4-xml php7.4-mbstring php7.4-curl php7.4-zip
    version="6.x"
elif [ $choice == "3" ]; then
    sudo apt-get update
    sudo apt-get install -y php7.4-cli php7.4-xml php7.4-mbstring php7.4-curl php7.4-zip
    version="7.x"
elif [ $choice == "4" ]; then
    sudo apt-get update
    sudo apt-get install -y php7.4-cli php7.4-xml php7.4-mbstring php7.4-curl php7.4-zip
    version="8.x"
else
    echo "Invalid option. Please enter 1, 2, 3 or 4."
    exit 1
fi

# Install Composer
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# Install Laravel
composer create-project --prefer-dist laravel/laravel project_name $version
