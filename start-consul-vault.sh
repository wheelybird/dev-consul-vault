#!/bin/bash

export volume_dir="${HOME}/docker_volumes"
export cert_dir="${volume_dir}/ssl"

#####################################################

if [ ! -d "$cert_dir" ]; then
 mkdir -p $cert_dir
fi

#####################################################

docker_cmd=`which docker`
if [ "$?" != "0" ] ; then
 echo
 echo "You need to install Docker."
 echo
 exit 1
fi

#####################################################

#Get the default interface's IP
def_if=`ip route | grep default | awk '{ print $5 }'`
host_ip=`ip -4 addr show $def_if | grep -oP '(?<=inet\s)\d+(\.\d+){3}'`
this_hostname=$HOSTNAME

#####################################################

if [ "${1}x" == "x" ]; then

 export this_fqdn="vault.localdomain"

else

 export this_fqdn=$1
 #sanitise the fqdn
 this_fqdn=`echo $this_fqdn | tr '[:upper:]' '[:lower:]' | sed -e 's/[^[:alpha:][:digit:]\.]/_/g' | sed -e 's/__*/_/g'`
 this_fqdn=`echo $this_fqdn | sed -e 's/_/-/g'`

fi



#####################################################

if [ ! -f "$cert_dir/vault.key" ]; then


 cat <<EoSan >$cert_dir/csr_config.txt
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C=GB
ST=London
L=London
O=Wheelybird
OU=Vault
CN=${this_fqdn}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
DNS.2 = vault
DNS.3 = $this_hostname
IP.1 = 127.0.0.1
IP.2 = $host_ip
EoSan

 cat <<EoSh >$cert_dir/generate_certs.sh
#!/bin/bash

#Server

echo "Generating CA key..."
openssl genrsa -out /tmp/ca.key 2048

echo "Generating CA cert..."
openssl req \
    -new \
    -x509 \
    -key /tmp/ca.key \
    -nodes \
    -days 7300 \
    -subj '/CN=VAULTCA/O=WHEELYBIRD/C=GB' \
    -out /tmp/ca.crt

echo "Generating server key..."
openssl genrsa -out /tmp/vault.key 2048

echo "Generating server signing request..."
openssl req \
    -new \
    -key /tmp/vault.key \
    -out /tmp/vault.csr \
    -config /tmp/csr_config.txt

echo "Generating server cert..."
openssl x509 \
    -sha256 \
    -req \
    -CA /tmp/ca.crt \
    -CAkey /tmp/ca.key \
    -CAcreateserial \
    -days 7300 \
    -in /tmp/vault.csr \
    -out /tmp/vault.crt \
    -extfile /tmp/csr_config.txt \
    -extensions req_ext

#Perms

chmod a+r /tmp/*

EoSh

 chmod a+x $cert_dir/generate_certs.sh

 #Build an alpine container with openssl and then use it to create the TLS certs
 docker build -t alpine-openssl .
 docker run --rm -ti -v $cert_dir:/tmp alpine-openssl /tmp/generate_certs.sh

fi


#####################################################


echo "Starting Consul..."

docker run \
             --name=consul \
             -d \
             --restart=unless-stopped \
             --add-host=vault:$host_ip \
             -p 8500:8500 \
             -p 8400:8400 \
             --volume=${volume_dir}/consul:/consul/data \
             consul:latest \
             agent -server -bootstrap-expect=1 -data-dir=/consul/data -ui -client=0.0.0.0



#####################################################

entrypoint_cmd=""

echo "Starting Vault..."

docker run \
             --name=vault \
             --hostname=vault \
             --add-host=consul:$host_ip \
             --add-host=vault:$host_ip \
             -d \
             --restart=unless-stopped \
             -p 8200:8200 \
             --volume=${PWD}/assets:/opt/assets \
             --volume=${volume_dir}/ssl:/opt/ssl \
             --entrypoint=sh \
             vault:latest \
                 -c "/opt/assets/waitfor.sh consul:8500 -q -t 20 -- vault server -config=/opt/assets/vault-config.hcl"


#####################################################
 
 echo "Waiting for everything to start fully..."

 sleep 5
 ${PWD}/assets/waitfor.sh 127.0.0.1:8200 -t 20


#####################################################

export vault_init_file="${volume_dir}/vault_init.txt"

if [ ! -f "$vault_init_file" ] ; then

 #Initialise Vault via the API because the CLI command fills the output with loads of escape characters
 #which are very difficult to remove
 echo
 echo "Initialising Vault via curl..."
 echo
 curl --cacert ${volume_dir}/ssl/ca.crt -s -S --request PUT --data '{"secret_shares": 5, "secret_threshold": 3}' https://127.0.0.1:8200/v1/sys/init >$vault_init_file
 exits=$?
 echo
 echo "ERROR: Curl exit status is $exits"
 echo
 echo
 if [ "$exits" -ne "0" ]; then
  docker logs -t vault
  exit 1
 fi

fi


#####################################################

echo "Unsealing the Vault..."
echo

#Parse the JSON output to get three unseal keys
keys=`sed -E 's/.*keys":\[(.*)\],"keys_base64.*/\1/' $vault_init_file | sed -e 's/","/ /g' | sed -e 's/"//g' |  cut -d' ' -f3-`
export VAULT_TOKEN=`sed -E 's/.*root_token":"(.*)".*/\1/' $vault_init_file`
export VAULT_ADDR="https://vault:8200"
export VAULT_CACERT="/opt/ssl/ca.crt"

docker_unseal_opts="-ti -e VAULT_TOKEN -e VAULT_ADDR -e VAULT_CACERT vault vault operator unseal"

for key in $keys; do 

 echo "Unseal with key: ($key)..."
 docker exec -ti $docker_unseal_opts "$key"

done

#####################################################

echo
echo
echo "Root token:  $VAULT_TOKEN"
echo
echo
echo "All done."
echo

#####################################################

exit 0
