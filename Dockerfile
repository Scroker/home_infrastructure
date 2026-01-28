# STAGE 1: Compilazione del file Butane
FROM quay.io/coreos/butane:release AS compiler

WORKDIR /config
# Copia il tuo file .bu locale
COPY config.bu .

# Compila il file .bu in .ign (Ignition)
# Usiamo il flag --strict per essere sicuri che non ci siano errori
RUN /usr/local/bin/butane --strict config.bu > config.ign

# STAGE 2: Web Server per l'esposizione
FROM docker.io/library/nginx:alpine

# Rimuove la pagina di default di nginx
RUN rm /usr/share/nginx/html/*

# Copia il file Ignition compilato nello stage precedente
COPY --from=compiler /config/config.ign /usr/share/nginx/html/config.ign

# Espone la porta 80
EXPOSE 80