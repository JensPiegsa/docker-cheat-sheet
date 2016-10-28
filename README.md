[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=WZJTZ3V8KKARC) [![Fork on GitHub](https://img.shields.io/github/forks/badges/shields.svg?style=flat&label=Fork%20on%20GitHub&color=blue)](https://github.com/JensPiegsa/docker-cheat-sheet/edit/master/README.md#fork-destination-box)

*Content*

* [Terminology](#terminology)
* [Docker Client](#docker-client)
   * [Building Images](#building-images)
   * [Running Containers](#running-containers)
   * [Using Volumes](#using-volumes)
* [Docker Machine](#docker-machine)
* [Dockerfile](#dockerfile)
* [Best Practices](#best-practices)
* [Additional Material](#additional-material)

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

* *note: the filter flag `-f status=exited` may be omitted here since running containers can not be removed*

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

# Using Volumes

### Declare a volume via Dockerfile

```
RUN mkdir /data && echo "some content" > /data/file && chown -R daemon:daemon /data
VOLUME /data
```

* *note: after the `VOLUME` directive, its content can not be changed within the Dockerfile*


### Create a volume at runtime
    docker run -it -v /data debian /bin/bash

### Create a volume at runtime bound to a host directory
    docker run --rm -v /tmp:/data debian ls -RAlph /data

### Create a named volume and use it

```sh
docker volume create --name=test
docker run --rm -it -v test:/data alpine sh -c 'echo "Hello named volumes" > /data/hello.txt'
docker run --rm -it -v test:/data alpine sh -c 'cat /data/hello.txt'
```

### Copy a file from host to named volume

```sh
echo "debug=true" > test.cnf && \
docker volume create --name=conf && \
docker run --rm -it -v $(pwd):/src -v conf:/dest alpine cp /src/test.cnf /dest/ && \
rm -f test.cnf && \
docker run --rm -it -v conf:/data alpine cat /data/test.cnf
```

### List the content of a volume
    docker run --rm -v data:/data alpine ls -RAlph /data

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

# Best Practices

## Docker Command

* `docker exec` is your friend in development, but should be avoided in a production setup

## Volumes

* use *named volumes* to simplify maintenance by separating persistent data from the container and communicating the structure of a project in a more transparent manner

## Dockerfile

* use `ENTRYPOINT` and `CMD` directives together to make container usage more convenient
* combine consecutive `RUN` directives with `&&` to reduce the costs of a build and to avoid caching of instructions like `apt-get update`
* use `EXPOSE` to document all needed ports

# Additional Material

* Mouat, A. (2015). *Using Docker: Developing and Deploying Software with Containers.* O'Reilly Media. ([English](http://shop.oreilly.com/product/0636920035671.do), [German](https://www.dpunkt.de/buecher/12553/9783864903847-docker.html))
* [Official Docker Documentation](https://docs.docker.com/)
* [StackOverflow Documentation](http://stackoverflow.com/documentation/docker/topics)

