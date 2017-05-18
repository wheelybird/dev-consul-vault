## Bring up Hashicorp Consul & Vault Docker containers with persistent data in development environments

The aim of this is to give developers an easy way to run Consul and Vault locally and to persist the Consul/Vault data between restarts.   

Simply run the `start-consul-vault.sh` to bring up a Consul/Vault stack.
These won't run in the in-memory `-dev` mode; Consul will run in a cluster of one node with storage on disk and Vault will use Consul as its storage backend.  The Consul container will expose the data directory as a volume.   

The startup script will also automatically (if necessary) initialise the Vault and unseal it for you.
The Vault root token is stored in `./.vault_init.txt` once the Vault container has been initialised (when `start-consul-vault.sh` is run for the first time).

To bring the container stack up you'll need:   

 * Docker   
 * Docker-compose:  https://docs.docker.com/compose/install/
 * Vault CLI:  https://www.vaultproject.io/downloads.html
 
Ensure the  vault and docker-compose binaries are in one of your `PATH` directories.
