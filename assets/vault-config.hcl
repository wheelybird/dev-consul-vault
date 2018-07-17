storage "consul" {
  address = "consul:8500"
  path = "vault"
  scheme = "http"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 0
  tls_disable_client_certs = 1
  tls_cert_file = "/opt/ssl/vault.crt"
  tls_key_file = "/opt/ssl/vault.key"
}

disable_mlock = true
ui = true
