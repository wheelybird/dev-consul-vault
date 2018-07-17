## Bring up Hashicorp Consul & Vault Docker containers with persistent data in development environments

The aim of this is to give developers an easy way to run Consul and Vault locally and to persist the Consul/Vault data between restarts.

Simply run `start-consul-vault.sh [FQDN]` to bring up a Consul/Vault stack, where FQDN is an optional fully-qualified domain name for the Vault server (e.g. vault.mydomain.org).  If you omit the FQDN argument then the host's hostname is used instead.

Consule and Vault won't run in the in-memory `-dev` mode; Consul will run in a cluster of one node with storage on disk and Vault will use Consul as its storage backend.  The Consul container will expose the data directory as a volume.   The default volume directory is {your home directory}/docker_volumes.  Modify `volume_dir` in `start-consul-vault.sh` to change that.

The startup script will also automatically initialise the Vault and unseal it for you.
The Vault root token is stored in `${volume_dir}/.vault_init.txt` once the Vault container has been initialised (when `start-consul-vault.sh` is run for the first time).

The startup script will generate server certificates, keys and a CA certificate based on the FQDN (or hostname if that's not set.  Those files are stored in `$volume_dir/ssl`.  To use your own certificates you can simply replace the automatically generated keys/certs with your own and re-run `start-consul-vault.sh`

To use Vault you'll need the CLI binary.  You can use the binary in the container (e.g. `docker run -ti vault vault status`) or you can download it from https://www.vaultproject.io/downloads.html
 
