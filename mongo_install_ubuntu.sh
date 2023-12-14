#!/bin/bash

# This script is designed for installing MongoDB V5 in Ubuntu VERSION="20.04.6 LTS (Focal Fossa) and expecting to be run as root user

# Run below commands if it is a fresh ubuntu base installation, so that we have all required packages to proceed with installation
: '
apt update
apt install -y sudo
apt install -y systemctl
'

# Import the public key used by the package management system
sudo apt-get install -y gnupg curl

curl -fsSL https://pgp.mongodb.com/server-5.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-5.0.gpg \
   --dearmor

# Create a list file for MongoDB
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-5.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list

# Reload local package database
sudo apt update

# Install the MongoDB packages
sudo apt-get install -y mongodb-org

# Creating directories for each members and assigning ownership to mongodb user
sudo mkdir -p /data/db_27017/ /data/db_27018/ /data/db_27019/
sudo chown -R mongodb:mongodb /data/db_27017/ /data/db_27018/ /data/db_27019/

# Taking backup of conf before mofifying. (Here I am modifying default port and java security in mongod.conf and remaining using mongod commands to show the use cases of both)
cp /etc/mongod.conf /etc/mongod.conf.bak
sudo sed -i '/#security:/a security:\n  javascriptEnabled: false' /etc/mongod.conf
sudo sed -i 's/^ *port:.*$/  port: 27015/' /etc/mongod.conf

# Start mongod daemon service 
sudo systemctl start mongod

# Configuring member nodes using mongod daemon, it is also possible to modify by configuring "/etc/mongod.conf" file and specifying --config in the below command to use the required config file
# By default it uses "/etc/mongod.conf" file for values until explicitly specified in the below mongod commands

mongod --port 27017 --dbpath /data/db_27017/ --logpath /data/db_27017/mongod_27017.log --replSet rs0 --wiredTigerCacheSizeGB 1 --fork --bind_ip_all
mongod --port 27018 --dbpath /data/db_27018/ --logpath /data/db_27018/mongod_27018.log --replSet rs0 --wiredTigerCacheSizeGB 1 --fork --bind_ip_all
mongod --port 27019 --dbpath /data/db_27019/ --logpath /data/db_27019/mongod_27019.log --replSet rs0 --wiredTigerCacheSizeGB 1 --fork --bind_ip_all

# Initiating replication and setting first member to primary and the third member to arbiter
mongosh --host localhost:27017 <<EOF
rs.initiate({
  _id: "rs0",
members: [
    { _id: 0, host: "localhost:27017", priority: 2 },
    { _id: 1, host: "localhost:27018" },
    { _id: 2, host: "localhost:27019", arbiterOnly: true}
  ]
})
EOF