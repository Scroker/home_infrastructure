FROM docker.io/alpine:latest

RUN apk add --no-cache nut

RUN mkdir -p /var/run/nut
RUN chmod 700 /var/run/nut
RUN chown -R nut:nut /var/run/nut 
RUN chown -R nut:nut /etc/nut

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
EXPOSE 3493

USER nut

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]