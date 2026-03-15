#!/bin/sh

# Assicuriamoci che la directory esista e sia dell'utente nut
mkdir -p /var/run/nut
chown nut:nut /var/run/nut
chmod 770 /var/run/nut

# Avvia il driver (come root per l'USB)
# -u root è fondamentale qui
/usr/sbin/upsdrvctl -u root start

# Aspetta un secondo che la socket venga creata
sleep 2

# Avvia il server (upsd)
# Lo forziamo a girare come utente 'nut' e in foreground
exec /usr/sbin/upsd -u nut -D
