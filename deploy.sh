#!/bin/sh

# Load environment variables from .env file
set -a
source .env
set +a

HOSTIP=$(ipconfig getifaddr en0)
echo $HOSTIP

### DEPLOY VAULT 

export VAULT_ADDR=http://${HOSTIP}:8200
echo $VAULT_ADDR

echo "vault namespace:"
echo $VAULT_NAMESPACE

unset VAULT_NAMESPACE
echo "vault namespace:"
echo $VAULT_NAMESPACE

vault operator init -key-shares=1  -key-threshold=1 --format json >> init.txt
export ROOT_TOKEN=$(cat init.txt | jq -r .root_token)
export UNSEAL_KEY=$(cat init.txt | jq -r .unseal_keys_b64[0])

echo 'root token & unseal key:'
echo $ROOT_TOKEN
echo $UNSEAL_KEY

export VAULT_TOKEN=$ROOT_TOKEN

vault operator unseal $UNSEAL_KEY
vault login $ROOT_TOKEN

vault token lookup

#Create admin user
echo '
path "*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}' | vault policy write vault_admin -

vault auth enable userpass
vault write auth/userpass/users/vault password=vault policies=vault_admin

vault secrets enable -path secret -version=2 kv

vault kv put secret/my-app-secret username=application-user password=application-password


## DEPLOY VAULT POLICIES

echo '
path "secret/data/my-secret" {
  capabilities = ["read"]
}

path "secret/data/my-app-secret" {
  capabilities = ["read"]
}' | vault policy write linux-ssh-policy -



