kitchen-dokken
==============

[![Build Status](https://travis-ci.org/someara/kitchen-dokken.svg?branch=master)](https://travis-ci.org/someara/kitchen-dokken)

Overview
--------

This test-kitchen plugin provides a driver, transport, and provisioner
for rapid cookbook testing and container development using Docker and Chef.

![Rokken.](http://i.onionstatic.com/onion/5507/4/16x9/1600.jpg)

Usage
--------
Add the following to your ~/.bash_profile
```
export KITCHEN_YAML=.kitchen.yml
export KITCHEN_LOCAL_YAML=.kitchen.dokken.yml
```

- Behold `.kitchen.yml`

```yaml
laptop:~/src/chef-cookbooks/hello_dokken$ cat .kitchen.yml
---
driver:
  name: dokken
  chef_version: latest

transport:
  name: dokken

provisioner:
  name: dokken

verifier:
  name: inspec

platforms:
- name: centos-7
  driver:
    image: centos:7

suites:
  - name: default
    run_list:
    - recipe[hello_dokken::default]
```

How it works
------------

### Primordial State
- List kitchen suites
```
laptop:~/src/chef-cookbooks/hello_dokken$ kitchen list
Instance          Driver  Provisioner  Verifier  Transport  Last Action
default-centos-7  Dokken  Dokken       Busser    Dokken     <Not Created>
```
- List containers
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker ps -a
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
```
- List images
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
```

### Create phase
```
laptop:~/src/chef-cookbooks/hello_dokken$ kitchen create
-----> Starting Kitchen (v1.4.2)
-----> Creating <default-centos-7>...
       Finished creating <default-centos-7> (0m35.33s).
-----> Kitchen is finished. (0m35.45s)
```

The `kitchen create` phase of the kitchen run pulls (if missing)
the `chef/chef` image from the Docker hub, then creates a volume
container named `chef-<version>`. This makes `/opt/chef` available for
mounting by other containers.

The driver then pulls the `someara/kitchen-cache` image and starts a
volume container named `<suite-name>-data`. This makes `/opt/kitchen`
and `/opt/verifier` available for mounting. This data container is the
"trick" to the whole thing. It comes with rsync, runs an openssh
daemon, and uses an, insecure, authorized_key ala Vagrant. This is
later used to upload cookbook test data. The venerable `/tmp`
directory is avoided, due to the popularity of `tmpfs` clobbering by
inits.

Finally, the driver pulls the image specified by the suite's platform
section and creates a runner container named `<suitename>`. This
container bind-mounts the volumes from `chef-<version>` and
`<suite-name>-data`, giving access to Chef and the test data. By
default, the `pid_one_command` of the runner container is a script
that sleeps in a loop, letting us `exec` our provisioner in the next
phase. It can be overridden with init systems like Upstart and
Systemd, for testing recipes with service resources as needed.

- List containers
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker ps -a
CONTAINER ID        IMAGE                          COMMAND                  CREATED             STATUS              PORTS                   NAMES
04f4b6908031        default-centos-7:latest        "sh -c 'trap exit 0 S"   3 minutes ago       Up 3 minutes                                default-centos-7
01b3c47bd7b8        someara/kitchen-cache:latest   "/usr/sbin/sshd -D -p"   3 minutes ago       Up 3 minutes        0.0.0.0:32845->22/tcp   default-centos-7-data
7e327add6bf2        chef/chef:latest               "true"                   3 minutes ago       Created                                     chef-12.5.1
laptop:~/src/chef-cookbooks/hello_dokken$
```

- List images

```
laptop:~/src/chef-cookbooks/hello_dokken$ docker images
REPOSITORY              TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
someara/kitchen-cache   latest              abbdb063dff1        2 weeks ago         300.8 MB
chef/chef               12.5.1              86245605bbe3        4 weeks ago         168.1 MB
centos                  7                   e9fa5d3a0d0e        6 weeks ago         172.3 MB
default-centos-7        latest              e9fa5d3a0d0e        6 weeks ago         172.3 MB
```

### Converge phase

- Converge suite
```
laptop:~/src/chef-cookbooks/hello_dokken$ time kitchen converge
-----> Starting Kitchen (v1.4.2)
-----> Creating <default-centos-7>...
       Finished creating <default-centos-7> (0m1.82s).
-----> Converging <default-centos-7>...
       Preparing files for transfer
       Preparing dna.json
       Preparing current project directory as a cookbook
       Removing non-cookbook files before transfer
       Preparing validation.pem
       Preparing client.rb
       Transferring files to <default-centos-7>
Starting Chef Client, version 12.17.44
[2016-12-29T05:35:03+00:00] WARN: unable to detect ipaddress
Creating a new client identity for default-centos-7 using the validator key.
resolving cookbooks for run list: ["hello_dokken::default"]
Synchronizing Cookbooks:
  - hello_dokken (0.1.0)
Compiling Cookbooks...
Converging 1 resources
Recipe: hello_dokken::default
  * file[/hello] action create
    - create new file /hello
    - update content in file /hello from none to 2d6944
    --- /hello	2015-12-18 05:35:04.220069059 +0000
    +++ /.hello20151218-27-1qrtph8	2015-12-18 05:35:04.220069059 +0000
    @@ -1 +1,2 @@
    +hello\n
    - change mode from '' to '0644'
    - change owner from '' to 'root'
    - change group from '' to 'root'

Running handlers:
Running handlers complete
Chef Client finished, 1/1 resources updated in 02 seconds
       Finished converging <default-centos-7> (0m10.98s).
-----> Kitchen is finished. (0m13.04s)

real	0m7.123s
user	0m1.128s
sys	0m0.246s
```

The `kitchen-converge` phase of the kitchen run uses the provisioner
to upload cookbooks through the data container, then execs
`chef-client` in the runner container. It does NOT install Chef, as it
is has already mounted by the driver. The transport then commits the
runner container, creating an image that only contains the changes
made by Chef.

- List containers
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker ps -a
CONTAINER ID        IMAGE                          COMMAND                  CREATED             STATUS              PORTS                   NAMES
c153dfd8e53d        e9fa5d3a0d0e                   "sh -c 'trap exit 0 S"   9 minutes ago       Up 9 minutes                                default-centos-7
32c42fba4a8c        someara/kitchen-cache:latest   "/usr/sbin/sshd -D -p"   9 minutes ago       Up 9 minutes        0.0.0.0:32846->22/tcp   default-centos-7-data
7e327add6bf2        chef/chef:12.5.1               "true"                   17 minutes ago      Created                                     chef-12.5.1
```

- List images
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker images
REPOSITORY              TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
default-centos-7        latest              ec1d208d77cd        8 minutes ago       172.3 MB
someara/kitchen-cache   latest              abbdb063dff1        2 weeks ago         300.8 MB
chef/chef               12.5.1              86245605bbe3        4 weeks ago         168.1 MB
centos                  7                   e9fa5d3a0d0e        6 weeks ago         172.3 MB
```

- Diff container
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker diff default-centos-7
A /]
A /[
A /hello
C /opt
A /opt/chef
A /opt/kitchen
A /opt/verifier
C /run
A /run/mount
A /run/mount/utab
```

### Verify phase
- Verify suite
```
laptop:~/src/chef-cookbooks/hello_dokken$  kitchen verify
-----> Starting Kitchen (v1.14.2) 
-----> Verifying <default-centos-7>...
       Loaded

Target:  docker://d5b23dc56d7dbd2604840fe43ebb0e1ae6b596bf3ffe94673e6fedfa67ff5f68

  File /hello
     ✔  should be file
     ✔  should be mode 420
     ✔  should be owned by "root"
     ✔  should be grouped into "root"

Test Summary: 4 successful, 0 failures, 0 skipped
       Finished verifying <default-centos-7> (0m0.91s).
-----> Kitchen is finished. (0m1.66s)
laptop:~/src/chef-cookbooks/hello_dokken$
```

The `kitchen-verify` phase uses the transport to run acceptance tests, verifying image state.

- List containers
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker ps -a
CONTAINER ID        IMAGE                          COMMAND                  CREATED             STATUS              PORTS                   NAMES
c153dfd8e53d        e9fa5d3a0d0e                   "sh -c 'trap exit 0 S"   15 minutes ago      Up 15 minutes                               default-centos-7
32c42fba4a8c        someara/kitchen-cache:latest   "/usr/sbin/sshd -D -p"   15 minutes ago      Up 15 minutes       0.0.0.0:32846->22/tcp   default-centos-7-data
7e327add6bf2        chef/chef:12.5.1               "true"                   24 minutes ago      Created                                     chef-12.5.1
```

- List images
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker images
REPOSITORY              TAG                 IMAGE ID            CREATED              VIRTUAL SIZE
default-centos-7        latest              bad9650b4d20        About a minute ago   175.3 MB
someara/kitchen-cache   latest              abbdb063dff1        2 weeks ago          300.8 MB
chef/chef               12.5.1              86245605bbe3        4 weeks ago          168.1 MB
centos                  7                   e9fa5d3a0d0e        6 weeks ago          172.3 MB
```

### Destroy phase
```
laptop:~/src/chef-cookbooks/hello_dokken$ kitchen destroy
-----> Starting Kitchen (v1.4.2)
-----> Destroying <default-centos-7>...
       Destroying container default-centos-7-data.
       Destroying container default-centos-7.
       Finished destroying <default-centos-7> (0m11.05s).
-----> Kitchen is finished. (0m11.22s)
```

- List containers
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker ps -a
CONTAINER ID        IMAGE                 COMMAND             CREATED             STATUS              PORTS               NAMES
7e327add6bf2        chef/chef:12.5.1      "true"              26 minutes ago      Created                                 chef-12.5.1
```

- List images
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker images
REPOSITORY              TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
someara/kitchen-cache   latest              abbdb063dff1        2 weeks ago         300.8 MB
chef/chef               12.5.1              86245605bbe3        4 weeks ago         168.1 MB
centos                  7                   e9fa5d3a0d0e        6 weeks ago         172.3 MB
```

Advanced Configuration
======================

Due to the nature of Docker, a handful of considerations need to be addressed.

A complete example of a non-trivial `kitchen.yml` is found in the `httpd` cookbook, at
https://github.com/chef-cookbooks/httpd/blob/master/.kitchen.yml

### Minimalist images
The Distros (debian, centos, etc) will typically manage an official image on the
Docker Hub. They are really pushing the boundaries of minimalist images, well
beyond what is typically laid to disk as part of a "base installation".

Very often, an image will come with a package manager, GNU coreutils, and
that's about it. This can differ greatly from what is found typical Vagrant and
IaaS images.

Because of this, it is often necessary to "cheat" and install prerequisites
into the image before running Chef, Serverspec, or your own programs.

To help with this, the Dokken driver provides an `intermediate_instructions`
directive. Here is an example from `httpd`

```
platforms:
- name: debian-7
  driver:
    image: debian:7
    intermediate_instructions:
      - RUN /usr/bin/apt-get update
      - RUN /usr/bin/apt-get install -y apt-transport-https net-tools
```

If present, an intermediate image is built, using a Dockerfile rendered from lines
provided. Any valid instruction will work, including `MAINTAINER`,
`ENTRYPOINT`, `VOLUMES`, etc. Knowledge of Docker is assumed.

This should be used as little as possible.

### Process orientation

Docker containers are process oriented rather than machine oriented. This makes life
interesting when testing things not necessarily destined to run in Docker. Specifically,
Chef recipes that utilize the `service` resource present a problem. To overcome this,
we run the container in a way that mimics a machine.

As mentioned previously, we use an infinite loop to keep the container process from exiting.
This allows us to do multiple `kitchen converge` and `kitchen login` operations without
needing to commit a layer and start a new container. This is fine until we need to start
testing recipes that use the `service` resource.

The default `pid_one_command` is `'sh -c "trap exit 0 SIGTERM; while :; do sleep 1; done"'`

If you need to use the service resource to drive Upstart or Systemd, you'll need to
specify the path to init. Here are more examples from `httpd`

- Systemd for RHEL-7 based platforms
```
platforms:
- name: centos-7
  driver:
    image: centos:7
    privileged: true
    pid_one_command: /usr/lib/systemd/systemd
```

You can combine `intermediate_instructions` and `pid_one_command` as needed.

- Upstart for Ubuntu 12.04
```
- name: ubuntu-12.04
  driver:
    image: ubuntu-upstart:12.04
    pid_one_command: /sbin/init
    intermediate_instructions:
      - RUN /usr/bin/apt-get update
      - RUN /usr/bin/apt-get install apt-transport-https
```

### Tmpfs on /tmp

When starting a container with an init system, it will often mount a tmpfs into `/tmp`.
When this happens, it is necessary to specify a `root_path` for the verifier if using
traditional Bats or Serverspec. This is due to Docker bind mounting the kitchen data
before running init. This is not necessary when using Inspec.

```
verifier:
  root_path: '/opt/verifier'
  sudo: false
```

### Install Chef from current channel

Chef publishes all functioning builds to the [Docker Hub](https://hub.docker.com/r/chef/chef/tags),
including those from the "current" channel. If you wish to use pre-release versions of Chef, set
your `chef_version` value to "current".

FAQ
===

### What about kitchen-docker?
We already had a thing that drives Docker, why did you make this instead of modifying that?

The current `kitchen-docker` driver ends up baking SSH, Chef, and the kitchen data
into the image. This does not. To make this work, I had to create a Driver, a Transport,
and a Provisioner that blur the traditional duties of each. The current Docker driver
can be used with Puppet, Ansible, CFEngine provisioners. This (for the time being) requires
Chef.

It also relies on an image from the Docker Hub that currently lives in my personal namespace.
The `someara/kitchen-cache` image is probably not suitable for many of the
environments where kitchen-docker is currently in use.

### How can I use kitchen to automatically test and publish containers?

Right now there is no `kitchen publish` mechanism. [See this issue](https://github.com/test-kitchen/test-kitchen/issues/329).

You can, however, do it manually.

```
cd my_cookbook ;
kitchen verify suite_name
docker stop suite_name
docker tag suite_name:latest my.computers.biz:5043/something/whatever
docker push my.computers.biz:5043/something/whatever
kitchen destroy
```
