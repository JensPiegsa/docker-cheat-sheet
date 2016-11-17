#!/bin/bash
#
# NOTES: requires docker.
# certs remain in /tmp/registry.*

printf "\nPulling registry image ...\n" && \
docker pull registry ; \

printf "\nPreparing registry-cert volume ...\n" && \
docker volume create --name=registry-cert && \
cd /tmp && \
openssl genrsa -out registry.key 4096 && \
openssl req -new -nodes -sha256 -subj '/CN=localhost' -key /tmp/registry.key -out /tmp/registry.csr && \
openssl x509 -req -days 3650 -signkey /tmp/registry.key -in /tmp/registry.csr -out /tmp/registry.pem && \
docker run --rm -it -v /tmp:/from -v registry-cert:/to --entrypoint sh registry \
 -c 'cp /from/registry.key /to && cp /from/registry.pem /to' && \

printf "\nLetting docker client trust certificate ...\n" && \
if [ -d /var/lib/boot2docker ] ;
then
    sudo mkdir -p /var/lib/boot2docker/certs && \
    sudo cp /tmp/registry.pem /var/lib/boot2docker/certs
else
    sudo mkdir -p /etc/docker/certs.d/localhost && \
    sudo cp /tmp/registry.pem /etc/docker/certs.d/localhost
fi && \

printf "\nPreparing registry-auth volume (please change 'reg_user' and 'reg_password') ...\n" && \
docker volume create --name=registry-auth && \
docker run --rm --entrypoint /bin/sh -v registry-auth:/auth registry \
 -c 'htpasswd -Bbn reg_user reg_password > /auth/htpasswd' && \

printf "\nPreparing registry-data volume ...\n" && \
docker volume create --name=registry-data && \

printf "\nRunning registry container ...\n" && \
docker run --name registry -h registry -d \
-v registry-data:/var/lib/registry \
-v registry-auth:/auth:ro \
-v registry-cert:/certs:ro \
--restart=always \
-p 5000:5000 \
-e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.pem \
-e REGISTRY_AUTH=htpasswd \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
-e REGISTRY_STORAGE_DELETE_ENABLED=true \
registry

