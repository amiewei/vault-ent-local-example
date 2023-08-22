#!/bin/sh

HOSTIP=$(ipconfig getifaddr en0)

# Create the vault.config file
cat <<EOL > config/vault/config/vault.hcl
storage "raft" {
  path    = "/vault/file"
  node_id = "node1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr     = "http://${HOSTIP}:8200"
cluster_addr = "http://${HOSTIP}:8201"
ui           = true
EOL

echo "List files in /vault/config after generation:"
ls -l config/vault/config