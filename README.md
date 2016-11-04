[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=WZJTZ3V8KKARC)
[![Fork on GitHub](https://img.shields.io/github/forks/badges/shields.svg?style=flat&label=Fork%20on%20GitHub&color=blue)](https://github.com/JensPiegsa/docker-cheat-sheet/edit/master/README.md#fork-destination-box)
[![Issues](https://img.shields.io/github/issues-raw/badges/shields.svg?style=flat&label=Comments%2FIssues)](https://github.com/JensPiegsa/docker-cheat-sheet/issues)

This document is hosted at [docker.jens-piegsa.com](http://docker.jens-piegsa.com/).

# Content

* [1. Fundamentals](#1-fundamentals)
	* [1.1. Concepts](#11-concepts)
	* [1.2. Lifecycle](#12-lifecycle)
* [2. Recipes](#2-recipes)
	* [2.1. Docker Engine](#21-docker-engine)
		* [2.1.1. Building Images](#211-building-images)
		* [2.1.2. Running Containers](#212-running-containers)
		* [2.1.3. Using Volumes](#213-using-volumes)
	* [2.2. Docker Machine](#22-docker-machine)
	* [2.3. Dockerfile](#23-dockerfile)
* [3. Showcases](#3-showcases)
	* [3.1. Private Docker Registry](#31-private-docker-registry)
	* [3.2. Continuous Integration Tool Stack](#32-continuous-integration-tool-stack)
* [4. Best Practices](#4-best-practices)
* [5. Additional Material](#5-additional-material)

# 1. Fundamentals

# 1.1. Concepts

* **Union file system (UFS)**: allows to overlay multiple file systems appearing as a single system whereby equal folders are merged and equally named files hide their previous versions
* **Image**: a portable read-only file system layer optionally stacked on a parent image
* **Dockerfile**: used to `build` an image and declare the command executed in the container
* **Registry**: is the place where to `push` and `pull` from named / tagged images 
* **Container**: an instance of an image with a writable file system layer on top, virtual networking, ready to execute a single application 
* **Volume**: a directory outside the UFS that can be mounted inside containers for persistent and shared data 
* **Network**: acts as a namespace for containers
* **Service**: a flexible number of container replicas running on a cluster of multiple hosts

# 1.2. Lifecycle

*A typical `docker` workflow:*

* `build` an image based on a `Dockerfile`
* `tag` and `push` the image to a *registry*
* `login` to the registry from the runtime environment to `pull` the image
* optionally `create` a `volume` or two to provide configuration files and hold data that needs to be persisted 
* `run` a container based on the image
* `stop` and `start` the container if necessary
* `commit` the container to turn it into an image
* in exceptional situations, `exec` additional commands inside the container
* to replace a container with an updated version 
	* `pull` the new image from the registry
	* `stop` the running container
	* backup your volumes to be prepared for a potential rollback
	* `run` the newer one by specifying a temporary name
	* if successful, `remove` the old container and `rename` the new one accordingly
 
# 2. Recipes

## 2.1. Docker Engine

### 2.1.1. Building Images

#### Debug image build

* `docker build` shows the IDs of all temporary containers and intermediate images
* use `docker run -it IMAGE_ID` with the ID of the image resulting from the last successful build step and try the next command manually

### 2.1.2. Running Containers

#### Start container and run command inside

```sh
docker run -it ubuntu:14.04 /bin/bash
```

#### Start a shell in a running container

```sh
docker exec -it CONTAINER /bin/bash
```

#### Start a container as another user

```sh
docker run -u root IMAGE
```

#### List all existing containers

```sh
docker ps -a
```

#### List running processes inside a container

```sh
docker top CONTAINER
```
     
#### Follow the logs

```sh
docker -f --tail=1000 CONTAINER
```

#### Stop all running containers

```sh
docker stop $(docker ps -q)
```

#### Remove all stopped containers, except those suffixed '-data':


```sh
docker ps -a -f status=exited | grep -v '\-data *$'| awk '{if(NR>1) print $1}' | xargs -r docker rm
```

#### Remove all stopped containers (warning: removes data-only containers too)

```sh
docker rm $(docker ps -qa -f status=exited)
```

* *note: the filter flag `-f status=exited` may be omitted here since running containers can not be removed*

#### List all images

```sh
docker images -a
```

#### Remove all unused images

```sh
docker rmi $(docker images -qa -f dangling=true)
```

#### Show image history of container

```sh
docker history --no-trunc=true $(docker inspect -f '{{.Image}}' CONTAINER)
```

#### Show file system changes compared to the original image

```sh
docker diff CONTAINER
```

#### Backup volume to host directory

```sh
docker run -rm --volumes-from SOURCE_CONTAINER -v $(pwd):/backup busybox \
 tar cvf /backup/backup.tar /data
```

#### Restore volume from host directory

```sh
docker run -rm --volumes-from TARGET_CONTAINER -v $(pwd):/backup busybox tar xvf /backup/backup.tar
```

#### Show volumes

```sh
docker inspect -f '{{range $v, $h := .Config.Volumes}}{{$v}}{{end}}' CONTAINER
```

#### Start all paused / stopped containers

* does not work together with container dependencies

#### Remove all containers and images

```sh
docker stop $(docker ps -q) && docker rm $(docker ps -qa) && docker rmi $(docker images -qa)
```

#### Edit and update a file in a container

```sh
docker cp CONTAINER:FILE /tmp/ && docker run --name=nano -it --rm -v /tmp:/tmp \
 piegsaj/nano nano /tmp/FILE ; \
cat /tmp/FILE | docker exec -i CONTAINER sh -c 'cat > FILE' ; \
rm /tmp/FILE
```

#### Deploy war file to Apache Tomcat server instantly

```sh
docker run -i -t -p 80:8080 -e WAR_URL=“<http://web-actions.googlecode.com/files/helloworld.war>” \
 bbytes/tomcat7
```

#### Dump a Postgres database into current directory on the host

```sh
echo "postgres_password" | sudo docker run -i --rm --link db:db -v $PWD:/tmp postgres:8 sh -c ' \
 pg_dump -h ocdb -p $OCDB_PORT_5432_TCP_PORT -U postgres -F tar -v openclinica \
 > /tmp/ocdb_pg_dump_$(date +%Y-%m-%d_%H-%M-%S).tar'
```

#### Backup data folder

```sh
docker run --rm --volumes-from oc-data -v $PWD:/tmp piegsaj/openclinica \
 tar cvf /tmp/oc_data_backup_$(date +%Y-%m-%d_%H-%M-%S).tar /tomcat/openclinica.data
```

#### Restore volume from data-only container

```sh
docker run --rm --volumes-from oc-data2 -v $pwd:/tmp piegsaj/openclinica \
 tar xvf /tmp/oc_data_backup_*.tar
```

#### Get the IP address of a container

```sh
docker inspect container_id | grep IPAddress | cut -d '"' -f 4
```

## 2.1.3. Using Volumes

#### Declare a volume via Dockerfile

```
RUN mkdir /data && echo "some content" > /data/file && chown -R daemon:daemon /data
VOLUME /data
```

* *note: after the `VOLUME` directive, its content can not be changed within the Dockerfile*

#### Create a volume at runtime

```sh
docker run -it -v /data debian /bin/bash
```

#### Create a volume at runtime bound to a host directory

```sh
docker run --rm -v /tmp:/data debian ls -RAlph /data
```

#### Create a named volume and use it

```sh
docker volume create --name=test
docker run --rm -v test:/data alpine sh -c 'echo "Hello named volumes" > /data/hello.txt'
docker run --rm -v test:/data alpine sh -c 'cat /data/hello.txt'
```

#### List the content of a volume

```sh
docker run --rm -v data:/data alpine ls -RAlph /data
```

#### Copy a file from host to named volume

```sh
echo "debug=true" > test.cnf && \
docker volume create --name=conf && \
docker run --rm -it -v $(pwd):/src -v conf:/dest alpine cp /src/test.cnf /dest/ && \
rm -f test.cnf && \
docker run --rm -it -v conf:/data alpine cat /data/test.cnf
```

#### Copy content of existing named volume to a new named volume

```sh
docker volume create --name vol_b
docker run --rm -v vol_a:/source/folder -v vol_b:/target/folder -it \
 rawmind/alpine-base:0.3.4 cp -r /source/folder /target
```

#### Remove unused images

```sh
docker volume rm $(docker volume ls -qf dangling=true)
```

## 2.2. Docker Machine

### On a local VM

#### Get the IP address of the virtual machine for access from host

```
docker-machine ip default
```

#### Add persistent environment variable to boot2docker

```sh
sudo echo 'echo '\''export ENVTEST="Hello Env!"'\'' > /etc/profile.d/custom.sh' | \
sudo tee -a /var/lib/boot2docker/profile > /dev/null
```

and restart with `docker-machine restart default`

#### Install additional linux packages in boot2docker

* create the file `/var/lib/boot2docker/bootsync.sh` with a content like:

```sh
#!/bin/sh
sudo /bin/su - docker -c 'tce-load -wi nano'
```

#### Recreate any folders and files on boot2docker startup

* store folders / files in `/var/lib/boot2docker/restore-on-boot` and
* create the file `/var/lib/boot2docker/bootsync.sh` with a content like:

```sh
#!/bin/sh
sudo mkdir -p /var/lib/boot2docker/restore-on-boot && \
sudo rsync -a /var/lib/boot2docker/restore-on-boot/ /
```

## 2.3. Dockerfile

#### Add a periodic health check

```
HEALTHCHECK --interval=1m --timeout=3s --retries=5 \
 CMD curl -f <http://localhost/> || exit 1
```

* see also: [HEALTHCHECK](https://docs.docker.com/engine/reference/builder/#/healthcheck)

# 3. Showcases

## 3.1. Private Docker Registry

#### Setup with docker-machine / boot2docker

``` sh
docker pull registry:2.5.1 ; \

# Prepare registry-cert volume
docker volume create --name=registry-cert && \
sudo mkdir -p /var/lib/boot2docker/certs/ && cd /var/lib/boot2docker/ && \
sudo openssl genrsa -out registry.key 4096 && \
sudo openssl req -new -nodes -sha256 -subj '/CN=localhost' -key registry.key -out registry.csr && \
sudo openssl x509 -req -days 3650 -signkey registry.key -in registry.csr -out certs/registry.pem && \
docker run --rm -it -v /var/lib/boot2docker/:/b2d -v registry-cert:/certs --entrypoint sh registry \
 -c 'cp /b2d/registry.key /certs/ && cp /b2d/certs/registry.pem /certs' && \

# Prepare registry-auth volume (please change 'reg_user' and 'reg_password')
docker volume create --name=registry-auth && \
docker run --rm --entrypoint /bin/sh -v registry-auth:/auth registry \
 -c 'htpasswd -Bbn reg_user reg_password > /auth/htpasswd' && \

# Prepare registry-data volume
docker volume create --name=registry-data && \

# Stop and remove existing container
{ docker stop registry ; docker rm registry ; } >/dev/null 2>&1 ; \

# Create container
docker run --name registry -h registry -d -l type=app "$ADD_HOST" \
-v registry-data:/var/lib/registry \
-v registry-auth:/auth \
-v registry-cert:/certs \
--restart=always \
-p 5000:5000 \
-e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.pem \
-e REGISTRY_AUTH=htpasswd \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
-e REGISTRY_STORAGE_DELETE_ENABLED=true \
registry
```

#### Usage example

``` sh
docker pull alpine:latest && \
docker login -u reg_user -p reg_password localhost:5000 && \
docker tag alpine:latest localhost:5000/alpine:private && \
docker rmi alpine:latest && \
docker push localhost:5000/alpine:private && \
docker rmi -f localhost:5000/alpine:private && \
docker pull localhost:5000/alpine:private && \
docker logout localhost:5000 && \
docker images | grep alpine && \
echo "Deleting image from registry..." && \
curl -X DELETE -u reg_user:reg_password \
https://localhost:5000/v2/alpine/manifests/$(docker images --digests | grep localhost:5000/alpine | awk '{print $3}')
```

#### Removal

``` sh
docker rm -f registry && \
docker volume rm registry-data registry-cert registry-auth
```

## 3.2. Continuous Integration Tool Stack

#### Setup with docker-machine / boot2docker

* make a directory called `ci` in your home directory on your host system and change into it

* create a file named `docker-compose.yml` with the following content:

```yaml
version: '2'

services:

  jenkins:
    image: jenkins
    ports:
      - "8082:8082"
      - "50000:50000"
    restart: always
    env_file: .env
    environment:
      - "JAVA_OPTS=-Dmail.smtp.starttls.enable=true -Dorg.apache.commons.jelly.tags.fmt.timeZone=Europe/Berlin"
      - "JENKINS_OPTS=--httpPort=8082"
    volumes:
      - jenkins_home:/var/jenkins_home
    
  nexus:
    image: sonatype/nexus3
    ports:
      - "8081:8081"
    restart: always
    env_file: .env
    volumes:
      - nexus-data:/nexus-data
    
  sonarqube:
    image: sonarqube
    ports:
      - "9000:9000"
    restart: always
    env_file:
      - .env
      - sonarqube.env
    environment:
      - SONARQUBE_JDBC_URL=jdbc:postgresql://postgres:5432/sonar
      - SONARQUBE_JDBC_USERNAME=sonar
    volumes:
      - sonarqube_conf:/opt/sonarqube/conf
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_bundled-plugins:/opt/sonarqube/lib/bundled-plugins
    links:
      - postgres

  postgres:
    image: postgres
    ports:
      - "5432:5432"
    restart: always
    env_file:
      - .env
      - sonarqube.env
    environment:
      - POSTGRES_USER=sonar
    volumes:
      - postgresql:/var/lib/postgresql
      - postgresql_data:/var/lib/postgresql/data

volumes:
  jenkins_home:
  nexus-data:
  sonarqube_conf:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_bundled-plugins:
  postgresql:
  postgresql_data:
```

* create a second file named `.env` that defines a timezone:

```
TZ=Europe/Berlin
```

* create a third file named `sonarqube.env` that holds the database passwords:

```
SONARQUBE_JDBC_PASSWORD=sonar
POSTGRES_PASSWORD=sonar
```

#### Usage

* startup all containers:

```
docker-compose up -d
```

* watch the logs, type `docker-compose logs` or `docker logs -f ci_jenkins_1`

* access the web applications:
	* Jenkins on port 8082
	* Sonatype Nexus on port 8081 and
	* SonarQube on port 9000

#### Removal

* to remove the tool stack (incl. data), use:

```
docker-compose stop && docker-compose rm -fav
```

# 4. Best Practices

## Docker Engine

* `docker exec` is your friend in development, but should be avoided in a production setup

## Volumes

* use *named volumes* to simplify maintenance by separating persistent data from the container and communicating the structure of a project in a more transparent manner

## Dockerfile

* always set the `USER` statement, otherwise the container will run as `root` user by default, which maps to the `root` user of the host machine
* use `ENTRYPOINT` and `CMD` directives together to make container usage more convenient
* combine consecutive `RUN` directives with `&&` to reduce the costs of a build and to avoid caching of instructions like `apt-get update`
* use `EXPOSE` to document all needed ports

# 5. Additional Material

* [Mouat, A. (2015). *Using Docker: Developing and Deploying Software with Containers.* O'Reilly Media.](http://shop.oreilly.com/product/0636920035671.do) ([German Edition: *Docker. Software entwickeln und deployen mit Containern.* dpunkt.verlag](https://www.dpunkt.de/buecher/12553/9783864903847-docker.html))
* [Official Docker Documentation](https://docs.docker.com/)
* [Gupta, A. (2016). *Docker Container Anti Patterns.*](http://blog.arungupta.me/docker-container-anti-patterns/)
* [StackOverflow Documentation](http://stackoverflow.com/documentation/docker/topics)

---

{{ site.github.project_title }}

{{ build_revision }}
