[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=WZJTZ3V8KKARC) [![Fork on GitHub](https://img.shields.io/github/forks/badges/shields.svg?style=flat&label=Fork%20on%20GitHub&color=blue)](https://github.com/JensPiegsa/docker-cheat-sheet/edit/master/README.md#fork-destination-box)

*Content*

* [Terminology](#terminology)
* [Docker Client](#docker-client)
   * [Building Images](#building-images)
   * [Running Containers](#running-containers)
* [Docker Machine](#docker-machine)

# Terminology

* **Image**
* **Container**
* **Volume**
* **Network**
* **Service**

# Docker Client

## Building Images

### Debug image build

* `docker build` shows the IDs of all temporary containers and intermediate images
* use `docker run -it IMAGE_ID` with the ID of the image resulting from the last successful build step and try the next command manually

## Running Containers

### Start container and run command inside
    docker run -it ubuntu:14.04 /bin/bash

### Start a shell in a running container
    docker exec -it CONTAINER /bin/bash

### Stop all running containers
    docker stop $(docker ps -q)

### Remove all stopped containers, except those suffixed '-data':

```sh
docker ps -a -f status=exited | grep -v '\-data *$'| awk '{if(NR>1) print $1}' | xargs -r docker rm
```

### Remove all stopped containers (warning: removes data-only containers too)

```sh
docker rm $(docker ps -qa -f status=exited)
```

* *Note: the filter flag `-f status=exited` may be omitted here since running containers can not be removed*

### Remove all unused images

```sh
docker rmi $(docker images -qa -f dangling=true)
```

### Show image history of container

```sh
docker history --no-trunc=true $(docker inspect -f '{{.Image}}' CONTAINER)
```

### Show file system changes compared to the original image

```sh
docker diff CONTAINER
```

### Backup volume

```sh
docker run -rm --volumes-from SOURCE_CONTAINER -v $(pwd):/backup busybox \
 tar cvf /backup/backup.tar /data
```

### Restore volume
    docker run -rm --volumes-from TARGET_CONTAINER -v $(pwd):/backup busybox tar xvf /backup/backup.tar

### Show volumes
    docker inspect -f '{{range $v, $h := .Config.Volumes}}{{$v}}{{end}}' CONTAINER

### Start all paused / stopped containers

* makes no sense together with container dependencies

### Remove all containers and images
    docker stop $(docker ps -q) && docker rm $(docker ps -qa) && docker rmi $(docker images -qa)

### Edit and update a file in a container

```sh
docker cp CONTAINER:FILE /tmp/ && docker run --name=nano -it --rm -v /tmp:/tmp \
 piegsaj/nano nano /tmp/FILE ; \
cat /tmp/FILE | docker exec -i CONTAINER sh -c 'cat > FILE' ; \
rm /tmp/FILE
```

### Deploy war file to Apache Tomcat server instantly

```sh
docker run -i -t -p 80:8080 -e WAR_URL=“http://web-actions.googlecode.com/files/helloworld.war” \
 bbytes/tomcat7
```

### Dump a Postgres database into your current directory on the host

``` sh
echo "postgres_password" | sudo docker run -i --rm --link db:db -v $PWD:/tmp postgres:8 sh -c ' \
 pg_dump -h ocdb -p $OCDB_PORT_5432_TCP_PORT -U postgres -F tar -v openclinica \
 > /tmp/ocdb_pg_dump_$(date +%Y-%m-%d_%H-%M-%S).tar'
```

### Backup data folder

```sh
docker run --rm --volumes-from oc-data -v $PWD:/tmp piegsaj/openclinica \
 tar cvf /tmp/oc_data_backup_$(date +%Y-%m-%d_%H-%M-%S).tar /tomcat/openclinica.data
```

### Restore volume from data-only container

```sh
docker run --rm --volumes-from oc-data2 -v $pwd:/tmp piegsaj/openclinica \
 tar xvf /tmp/oc_data_backup_*.tar
```

### Copy content of existing named volume to a new named volume

```sh
docker volume create --name vol_b
docker run --rm -v vol_a:/source/folder -v vol_b:/target/folder -it \
 rawmind/alpine-base:0.3.4 cp -r /source/folder /target
```

### Get the IP address of a container

    docker inspect container_id | grep IPAddress | cut -d '"' -f 4

# Docker Machine

## On a local VM

### Get the IP address of the virtual machine for access from host

    docker-machine ip default

### Add persistent environment variable to boot2docker

```sh
sudo echo 'echo '\''export ENVTEST="Hello Env!"'\'' > /etc/profile.d/custom.sh' | \
sudo tee -a /var/lib/boot2docker/profile > /dev/null
```

and restart with `docker-machine restart default`

### Install additional linux packages in boot2docker

* create the file `/var/lib/boot2docker/bootsync.sh` with a content like:

```
#!/bin/sh
sudo /bin/su - docker -c 'tce-load -wi nano'
```

### Recreate any folders and files on boot2docker startup

* store folders / files in `/var/lib/boot2docker/restore-on-boot` and
* create the file `/var/lib/boot2docker/bootsync.sh` with a content like:

```
#!/bin/sh
sudo mkdir -p /var/lib/boot2docker/restore-on-boot &&
sudo rsync -a /var/lib/boot2docker/restore-on-boot/ /
```

# Dockerfile

### Add a periodic health check

```
HEALTHCHECK --interval=1m --timeout=3s --retries=5 \
 CMD curl -f http://localhost/ || exit 1
```

* see also: [HEALTHCHECK](https://docs.docker.com/engine/reference/builder/#/healthcheck)
