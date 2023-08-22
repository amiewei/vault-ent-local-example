#!/bin/sh

# Load environment variables from .env file
set -a
source .env
set +a

HOSTIP=$(ipconfig getifaddr en0)
echo $HOSTIP

### DEPLOY VAULT 

export VAULT_ADDR=http://${HOSTIP}:8200

vault operator init -key-shares=1  -key-threshold=1 --format json >> init.txt
export ROOT_TOKEN=$(cat init.txt | jq -r .root_token)
export UNSEAL_KEY=$(cat init.txt | jq -r .unseal_keys_b64[0])

echo 'root token & unseal key'
echo $ROOT_TOKEN
echo $UNSEAL_KEY

vault operator unseal $UNSEAL_KEY
vault login $ROOT_TOKEN


#Create admin user
echo '
path "*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}' | vault policy write vault_admin -

vault auth enable userpass
vault write auth/userpass/users/vault password=vault policies=vault_admin

vault secrets enable -path secret -version=2 kv
vault secrets enable database

vault kv put secret/my-app-secret username=application-user password=application-password


### DEPLOY VAULT POLICIES

echo '
path "secret/data/my-secret" {
  capabilities = ["read"]
}

path "secret/data/my-app-secret" {
  capabilities = ["read"]
}' | vault policy write linux-ssh-policy -


echo '
path "database/creds/dba" {
  capabilities = ["read"]
}' | vault policy write docker-db-policy -


#lease for token is 20min, and at half the lease time, boundary has job to auto-renew token from vault
export SERVER_CRED_STORE_TOKEN=$(vault token create \
    -no-default-policy=true \
    -policy="vault_admin" \
    -policy="linux-ssh-policy" \
    -orphan=true \
    -period=20m \
    -renewable=true \
    -format=json | jq -r .auth.client_token)

export DB_CRED_STORE_TOKEN=$(vault token create \
    -no-default-policy=true \
    -policy="docker-db-policy" \
    -orphan=true \
    -period=20m \
    -renewable=true \
    -format=json | jq -r .auth.client_token)


## echo out all the environment variables that's been set for troubleshooting
echo "K8S_CRED_STORE_TOKEN=$K8S_CRED_STORE_TOKEN"
echo "SERVER_CRED_STORE_TOKEN=$SERVER_CRED_STORE_TOKEN"
echo "DB_CRED_STORE_TOKEN=$DB_CRED_STORE_TOKEN"


export PG_DB="database";export PG_URL="postgres://postgres:secret@${HOSTIP}:5432/${database}?sslmode=disable"


vault write database/config/database \
      plugin_name=postgresql-database-plugin \
      connection_url="postgresql://{{username}}:{{password}}@${HOSTIP}:5432/database?sslmode=disable" \
      allowed_roles=dba \
      username="admin" \
      password="dbroot"



vault write database/roles/dba \
    db_name=database \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    ALTER USER \"{{name}}\" WITH SUPERUSER;" \
    default_ttl="1h" \
    max_ttl="24h"




