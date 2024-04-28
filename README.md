```
podman-compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot/ --dry-run -d geeno.com -d www.geeno.com --email dramisgiorgio@gmail.com
```

```
openssl req -new -newkey rsa:2048 -nodes -keyout web-service.key -out web-service.csr -subj "/C=IT/ST=Lazio/L=Roma/O=Organizzazione/OU=Unità Operativa/CN=server.example.com" -days 365 
```