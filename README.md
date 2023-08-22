1. Create .env file and input your vault enterprise license

```
VAULT_LICENSE=abcd
```

2. Create vault.hcl file by running

```
chmod +x generate-vault-config.sh
./generate-vault-config.sh
```

3. Test it out

```
docker compose up -d
```

4. Destroy all evidence

```
chmod +x destroy.sh
./destroy.sh
```

**🙅🏻‍♀️DEMO ONLY - NOT FOR PROD USE🙅🏻‍♀️**
