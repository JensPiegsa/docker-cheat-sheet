---
layout: "index"
author: "Jens Piegsa"
title: "Docker 1.13 Cheat Sheet"
summary: "Docker Cheat Sheet. Find, Copy and Paste, Anywhere."
---

[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=WZJTZ3V8KKARC)
[![Fork on GitHub](https://img.shields.io/github/forks/JensPiegsa/docker-cheat-sheet.svg?style=flat&label=Fork%20on%20GitHub&color=blue)](https://github.com/JensPiegsa/docker-cheat-sheet#fork-destination-box)
[![Issues](https://img.shields.io/github/issues-raw/JensPiegsa/docker-cheat-sheet.svg?style=flat&label=Comments%2FIssues)](https://github.com/JensPiegsa/docker-cheat-sheet/issues)

//[docker](http://docker.jens-piegsa.com/).[jens-piegsa.com](http://jens-piegsa.com/)/

# Content

* [1. Fundamentals](#fundamentals)
	* [1.1. Concepts](#concepts)
	* [1.2. Lifecycle](#lifecycle)
* [2. Recipes](#recipes)
	* [2.1. Docker Engine](#docker-engine)
		* [2.1.1. Building Images](#building-images)
		* [2.1.2. Running Containers](#running-containers)
		* [2.1.3. Using Volumes](#using-volumes)
	* [2.2. Docker Machine](#docker-machine)
	* [2.3. Dockerfile](#dockerfile)
	* [2.4. Logging](#logging)
* [3. Showcases](#showcases)
	* [3.1. Private Docker Registry](#private-docker-registry)
	* [3.2. Continuous Integration Tool Stack](#continuous-integration-tool-stack)
* [4. Best Practices](#best-practices)
* [5. Additional Material](#additional-material)

# 1. Fundamentals

## 1.1. Concepts

* **Union file system (UFS)**: allows to overlay multiple file systems appearing as a single system whereby equal folders are merged and equally named files hide their previous versions
* **Image**: a portable read-only file system layer optionally stacked on a parent image
* **Dockerfile**: used to `build` an image and declare the command executed in the container
* **Registry**: is the place where to `push` and `pull` from named / tagged images 
* **Container**: an instance of an image with a writable file system layer on top, virtual networking, ready to execute a single application 
* **Volume**: a directory outside the UFS that can be mounted inside containers for persistent and shared data 
* **Network**: acts as a namespace for containers
* **Service**: a flexible number of container replicas running on a cluster of multiple hosts

## 1.2. Lifecycle

*A typical `docker` workflow:*

* `build` an image based on a `Dockerfile`
* `tag` and `push` the image to a *registry*
* `login` to the registry from the runtime environment to `pull` the image
* optionally `create` a `volume` or two to provide configuration files and hold data that needs to be persisted 
* `run` a container based on the image
* `stop` and `start` the container if necessary
* `commit` the container to turn it into an image (note: makes the image harder to reproduce)
* in exceptional situations, `exec` additional commands inside the container
* to replace a container with an updated version:
	* `pull` the new image from the registry
	* `stop` the running container
	* backup your volumes to be prepared for a potential rollback
	* `run` the newer one by specifying a temporary name
	* if successful, `remove` the old container and `rename` the new one accordingly
 
# 2. Recipes

## 2.1. Docker Engine

#### Show docker disk usage

``` sh
docker system df
```

#### Remove unused data

``` sh
docker system prune
```

{: .note}
This prompts for confirmation and will remove:
all stopped containers,
all volumes not used by at least one container,
all networks not used by at least one container and
all dangling images

### 2.1.1. Building Images

#### Debug image build

* `docker image build` shows the IDs of all temporary containers and intermediate images
* use `docker container run -it IMAGE_ID` with the ID of the image resulting from the last successful build step and try the next command manually

#### List all local tags for the same image

``` sh
{% raw %}
docker image ls --no-trunc | grep $(docker image inspect -f {{.Id}} IMAGE:TAG)
{% endraw %}
```

### 2.1.2. Running Containers

#### Start container and run command inside

```sh
docker container run -it ubuntu:14.04 /bin/bash
```

#### Start a shell in a running container

```sh
docker container exec -it CONTAINER /bin/bash
```

#### Start a container as another user

```sh
docker container run -u root IMAGE
```

#### List all existing containers

```sh
docker container ls -a
```

#### List running processes inside a container

```sh
docker container top CONTAINER
```
     
#### Follow the logs

```sh
docker container logs -f --tail=1000 CONTAINER
```

#### Stop all running containers

```sh
docker container stop $(docker container ls -q)
```

#### Remove all stopped containers, except those suffixed '-data':

```sh
docker container ls -a -f status=exited | grep -v '\-data *$'| awk '{if(NR>1) print $1}' | xargs -r docker container rm
```

#### Remove all stopped containers (warning: removes data-only containers too)

```sh
docker container prune
```

#### List all images

```sh
docker image ls -a
```

#### Remove all unused images

```sh
docker image prune
```

#### Show image history of container

```sh
{% raw %}
docker image history --no-trunc=true $(docker container inspect -f '{{.Image}}' CONTAINER)
{% endraw %}
```

#### Show file system changes compared to the original image

```sh
docker container diff CONTAINER
```

#### Backup directory content from container to host directory

```sh
docker container run --rm --volumes-from SOURCE_CONTAINER:ro -v $(pwd):/backup alpine \
 tar cvf /backup/backup_$(date +%Y-%m-%d_%H-%M).tar /data
```

#### Restore directory content to container from host directory

```sh
docker container run --rm --volumes-from TARGET_CONTAINER:ro -v $(pwd):/backup alpine \
 tar xvf /backup/backup.tar
```

#### Show names of volumes used by a container 

```sh
{% raw %}
docker container inspect -f '{{ range .Mounts }}{{ .Name }} {{ end }}' CONTAINER
{% endraw %}
```

#### Show names and mount point destinations of volumes used by a container 

```sh
{% raw %}
docker container inspect -f '{{ range .Mounts }}{{ .Name }}:{{ .Destination }} {{ end }}' CONTAINER
{% endraw %}
```

#### Start all paused / stopped containers

* does not work together with container dependencies

#### Edit and update a file in a container

```sh
docker container cp CONTAINER:FILE /tmp/ && docker container run --name=nano -it --rm -v /tmp:/tmp \
 piegsaj/nano nano /tmp/FILE ; \
cat /tmp/FILE | docker container exec -i CONTAINER sh -c 'cat > FILE' ; \
rm /tmp/FILE
```

#### Deploy war file to Apache Tomcat server instantly

```sh
docker container run -i -t -p 80:8080 -e WAR_URL=“<http://web-actions.googlecode.com/files/helloworld.war>” \
 bbytes/tomcat7
```

#### Dump a Postgres database into current directory on the host

```sh
echo "postgres_password" | sudo docker container run -i --rm --link db:db -v $PWD:/tmp postgres:8 sh -c ' \
 pg_dump -h ocdb -p $OCDB_PORT_5432_TCP_PORT -U postgres -F tar -v openclinica \
 > /tmp/ocdb_pg_dump_$(date +%Y-%m-%d_%H-%M-%S).tar'
```

#### Backup data folder

```sh
docker container run --rm --volumes-from oc-data -v $PWD:/tmp piegsaj/openclinica \
 tar cvf /tmp/oc_data_backup_$(date +%Y-%m-%d_%H-%M-%S).tar /tomcat/openclinica.data
```

#### Restore volume from data-only container

```sh
docker container run --rm --volumes-from oc-data2 -v $pwd:/tmp piegsaj/openclinica \
 tar xvf /tmp/oc_data_backup_*.tar
```

#### Get the IP address of a container

```sh
{% raw %}
docker container inspect -f '{{ .NetworkSettings.IPAddress }}' CONTAINER
{% endraw %}
```

### 2.1.3. Using Volumes

#### Declare a volume via Dockerfile

```
RUN mkdir /data && echo "some content" > /data/file && chown -R daemon:daemon /data
VOLUME /data
```

{: .note}
after the `VOLUME` directive, its content can not be changed within the Dockerfile

#### Create an anonymous volume at runtime

```sh
docker container run -it -v /data debian /bin/bash
```

#### Create a volume at runtime that is bound to a host directory

```sh
docker container run --rm -v /tmp:/data debian ls -RAlph /data
```

#### Create a named volume and use it

```sh
docker volume create --name=test
docker container run --rm -v test:/data alpine sh -c 'echo "Hello named volumes" > /data/hello.txt'
docker container run --rm -v test:/data alpine sh -c 'cat /data/hello.txt'
```

#### List the content of a volume

```sh
docker container run --rm -v data:/data alpine ls -RAlph /data
```

#### Copy a file from host to named volume

```sh
echo "debug=true" > test.cnf && \
docker volume create --name=conf && \
docker container run --rm -it -v $(pwd):/src -v conf:/dest alpine cp /src/test.cnf /dest/ && \
rm -f test.cnf && \
docker container run --rm -it -v conf:/data alpine cat /data/test.cnf
```

#### Copy content of existing volume to a new named volume

```sh
docker volume create --name VOL_B
```

* than:

```sh
docker container run --rm -v VOL_A:/source/folder:ro -v VOL_B:/target/folder \
 alpine cp -r /source/folder /target
```

or without the need for an intermediate directory (`cp` implementations differ):

```sh
 docker container run --rm -v VOL_A:/source:ro -v VOL_B:/target debian cp -TR /source /target
```

#### List all orphaned volumes

```sh
docker volume ls -qf dangling=true
```

#### Remove all orphaned volumes 

```sh
docker volume rm $(docker volume ls -qf dangling=true)
```

{: .note}
Caution, this also removes *named volumes* that are currently not mounted by any container!

#### Show names and mount point destinations of volumes used by a container

```sh
docker container inspect \
 -f '{{ range .Mounts }}{{ .Name }}:{{ .Destination }} {{ end }}' \
 CONTAINER
```

## 2.2. Docker Machine

### On a local VM

#### Get the IP address of the virtual machine for access from host

```
docker-machine ip default
```

#### Add persistent environment variable to boot2docker

```sh
echo 'echo '\''export ENVTEST="Hello Env!"'\'' > /etc/profile.d/custom.sh' | \
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

## 2.4. Logging

### Enable log rotation for Docker

* create the file `/etc/logrotate.d/docker` and insert:

```
/var/lib/docker/containers/*/*.log {
  daily
  rotate 14
  compress
  delaycompress
  missingok
  copytruncate
}
```

* check `/etc/cron.daily/logrotate` and `/etc/crontab` for general logrotate configuration.

{: .note}
This example will keep all container logs for 14 days.


# 3. Showcases

## 3.1. Private Docker Registry

#### Setup with boot2docker or natively on Linux

``` sh
printf "\nPulling registry image ...\n" && \
docker image pull registry ; \

printf "\nPreparing registry-cert volume ...\n" && \
docker volume create --name=registry-cert && \
cd /tmp && \
openssl genrsa -out registry.key 4096 && \
openssl req -new -nodes -sha256 -subj '/CN=localhost' -key /tmp/registry.key -out /tmp/registry.csr && \
openssl x509 -req -days 3650 -signkey /tmp/registry.key -in /tmp/registry.csr -out /tmp/registry.pem && \
docker container run --rm -it -v /tmp:/from -v registry-cert:/to --entrypoint sh registry \
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
docker container run --rm --entrypoint /bin/sh -v registry-auth:/auth registry \
 -c 'htpasswd -Bbn reg_user reg_password > /auth/htpasswd' && \

printf "\nPreparing registry-data volume ...\n" && \
docker volume create --name=registry-data && \

printf "\nRunning registry container ...\n" && \
docker container run --name registry -h registry -d \
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
```

* this script is also available at <http://docker.jens-piegsa.com/examples/setup-registry.sh>

#### Usage example

``` sh
docker image pull alpine:latest && \
docker login -u reg_user -p reg_password localhost:5000 && \
docker image tag alpine:latest localhost:5000/alpine:private && \
docker image rm alpine:latest && \
docker image push localhost:5000/alpine:private && \
docker image rm -f localhost:5000/alpine:private && \
docker image pull localhost:5000/alpine:private && \
docker logout localhost:5000 && \
docker image ls | grep alpine && \
printf "Deleting image from registry ...\n" && \
curl -X DELETE -u reg_user:reg_password --insecure \
https://localhost:5000/v2/alpine/manifests/$(docker image ls --digests | grep localhost:5000/alpine | awk '{print $3}')
```

#### Removal

``` sh
docker container rm -f registry && \
docker volume rm registry-data registry-cert registry-auth
```

#### Further Reading

* advanced authentication: [Docker Registry 2 authentication server](https://github.com/cesanta/docker_auth)
* developer notes about [deleting images from the registry](https://github.com/docker/distribution/blob/master/ROADMAP.md#deletes)

## 3.2. Continuous Integration Tool Stack

#### Setup with docker-machine / boot2docker

* make a directory called `ci` in your home directory on your host system and change into it

* create a file named `docker-compose.yml` with the following content:

``` yaml
version: "2"

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
docker-compose down -v
```

# 4. Best Practices

## Docker Engine

* `docker exec` is your friend in development, but should be avoided in a production setup

## Volumes

* use *named volumes* to simplify maintenance by separating persistent data from the container and communicating the structure of a project in a more transparent manner

## Dockerfile

* always keep environment configuration and secrets out of deployments and images, for example by using environment variables (`-e`, `--env-file`)
* always set the `USER` statement, otherwise the container will run as `root` user by default, which maps to the `root` user of the host machine
* use `ENTRYPOINT` and `CMD` directives together to make container usage more convenient
* coalesce consecutive `RUN` directives with `&&` to reduce the costs of a build and to avoid caching of instructions like `apt-get update`
* to reduce the size of an image, remove temporary resources in the same `RUN` statement that produces them (otherwise they are still present in an intermediate layer)
* use `EXPOSE` to document all needed ports
* introduce an additional build Dockerfile for your app, if you have a large set of compile-time dependencies ([build container pattern](http://blog.terranillius.com/post/docker_builder_pattern/)) 

# 5. Additional Material

* [Mouat, A. (2015). *Using Docker: Developing and Deploying Software with Containers.* O'Reilly Media.](http://shop.oreilly.com/product/0636920035671.do) ([German Edition: *Docker. Software entwickeln und deployen mit Containern.* dpunkt.verlag](https://www.dpunkt.de/buecher/12553/9783864903847-docker.html))
* [Turnbull, J. (2016). *The Docker Book. Containerization is the new Virtualization.*](https://www.dockerbook.com/)
* [Gupta, A. (2016). *Docker Container Anti Patterns.*](http://blog.arungupta.me/docker-container-anti-patterns/)
* [Piegsa, J. (2016). Dockerbank 2 Workshop. *Szenarien des Routinebetriebs.* (German Slides)](http://www.tmf-ev.de/Desktopmodules/Bring2Mind/DMX/Download.aspx?EntryId=29283&PortalId=0)
* [Official Docker Documentation](https://docs.docker.com/)
* [StackOverflow Documentation](http://stackoverflow.com/documentation/docker/topics)
* [Awesome Docker](https://veggiemonk.github.io/awesome-docker/)
* [Docker Labs](https://github.com/docker/labs)
* [Docker Introduction](http://view.dckr.info/DockerIntro.pdf)
* [play-with-docker.com](http://play-with-docker.com/)

---

## Contribute
{: .js-toc-ignore }

Feel free to fork this project, send me pull requests, and issues through the project's [GitHub page](https://github.com/JensPiegsa/docker-cheat-sheet/).
