#!/bin/bash

vault_cmd=`which vault`
if [ "$?" != "0" ] ; then
 echo
 echo "You need the vault binary to talk to the vault server."
 echo "Download it from here:  https://www.vaultproject.io/downloads.html"
 echo "and place somewhere in your PATH"
 echo
 exit 1
fi

docker_cmd=`which docker`
if [ "$?" != "0" ] ; then
 echo
 echo "You need to install Docker."
 echo
 exit 1
fi

compose_cmd=`which docker-compose`
if [ "$?" != "0" ] ; then
 echo
 echo "You need to install docker-compose: https://docs.docker.com/compose/install/"
 echo
 exit 1
fi

export VAULT_ADDR=http://127.0.0.1:8200

if ! [ -f .vault_init.txt ] ; then
 echo "Running Vault/Consul for the first time to initialise everything..."

 echo "Creating local volumes"
 mkdir -p ~/docker/volumes

 echo "Starting Consul & Vault"
 docker-compose up -d
 
 echo "Waiting for everything to start fully..."
 sleep 20
 
 echo "Initialising Vault..."
 vault init > .vault_init.txt

fi
 
echo "Getting root token..."
export VAULT_TOKEN=`grep 'Initial Root Token: ' .vault_init.txt | sed -e 's/Initial Root Token: //'`

echo "Unsealing the Vault..."
echo

echo "Unseal with key #1..."
vault unseal `grep 'Unseal Key 1: ' .vault_init.txt | sed -e 's/Unseal Key 1: //'`
echo "Unseal with key #2..."
vault unseal `grep 'Unseal Key 2: ' .vault_init.txt | sed -e 's/Unseal Key 2: //'`
echo "Unseal with key #2..."
vault unseal `grep 'Unseal Key 3: ' .vault_init.txt | sed -e 's/Unseal Key 3: //'`

echo "All done."
echo

exit 0
