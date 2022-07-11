# kitchen-dokken

[![Gem Version](https://badge.fury.io/rb/kitchen-dokken.svg)](https://badge.fury.io/rb/kitchen-dokken)

## Overview

This Test Kitchen plugin provides a driver, transport, and provisioner for rapid cookbook testing and container development using Docker and Chef Infra Client.

### Why should I use kitchen-dokken?

kitchen-dokken is fast. Really fast.

Test Kitchen itself has four components: Drivers, Transports, Provisioners, and Verifiers. Drivers are responsible for creating a system on local hypervisors or a cloud. Transports such as ssh or winrm are responsible for connecting to these hosts. Provisioners are responsible for provisioning the hosts to the desired state using scripts or configuration management tools. The final component is the verifier which is responsible for verifying the system state matches the desired state.

Unlike all other Test Kitchen drivers, kitchen-dokken handles all the tasks of the driver, transport, and provisioner itself. This approach requires a narrow focus of just Chef Infra cookbook testing, but provides ultra-fast testing times. Docker containers have a fast creation and start time, and dokken uses the official Chef Infra Client containers instead of spending the time to download and install the client. These design decisions result in tests that run in seconds instead of minutes and don't require high bandwidth Internet connections.

### kitchen-dokken vs. other drivers

As stated above kitchen-dokken is purpose-built for speed and it achieves this by narrowing the testing scope to just Chef Infra cookbook testing. Other drivers like kitchen-vagrant or kitchen-docker are general-purpose drivers that can be used with any of the Kitchen provisioners such as kitchen-puppet or kitchen-ansible. Also, keep in mind that testing with containers is not a perfect analog to a full-blown system. The dokken-images containers are designed to be similar to a standard OS install, but they do not perfectly match those installs and may need additional packages to work properly. If you're looking for a perfect analog to your production systems, without the additional work of package installation, then consider a driver such as kitchen-vagrant. If you're willing to potentially invest in a bit of package troubleshooting in exchange for faster feedback cycles then kitchen-dokken is for you.

## Usage

A sample kitchen-dokken `kitchen.yml` config:

```yaml
---
driver:
  name: dokken
  chef_version: latest # or 16 or 16.0 or 16.0.300 or current

transport:
  name: dokken

provisioner:
  name: dokken

verifier:
  name: inspec

platforms:
- name: centos-7
  driver:
    image: dokken/centos-7

suites:
  - name: default
    run_list:
    - recipe[hello_dokken::default]
```

## Podman usage

For specific podman guidance please see [the podman documentation](documentation/PODMAN.md).

## How it works

### Primordial State

#### List kitchen suites

```shell
$ kitchen list
Instance          Driver  Provisioner  Verifier  Transport  Last Action    Last Error
```

#### List containers

```shell
$ docker ps -a
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
```

#### List images

```shell
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
```

### Create phase

#### kitchen create

```shell
$ kitchen create
-----> Starting Kitchen (v1.15.0)
-----> Creating <default-centos-7>...
       Creating local sandbox at /Users/someara/.dokken/sandbox/6e1b03ab46-default-centos-7
       Building work image..
       Finished creating <default-centos-7> (0m21.04s).
-----> Kitchen is finished. (0m21.95s)
```

The `kitchen create` phase of the kitchen run pulls (if missing) the `chef/chef` image from the Docker hub, then creates a volume container named `chef-<version>`. This makes `/opt/chef` available for mounting by other containers.

When talking to a local Docker host (over a socket), the driver creates and bind mounts a sandbox directory to `/opt/kitchen`. This prevents us from having to "upload" the test data.

When talking to a *remote* Docker host (tcp://somewhere.else), dokken starts a container named `<suite-name>-data`. It makes `/opt/kitchen` and `/opt/verifier` available for mounting by the runner. The data container is the "trick" to the whole thing. It comes with rsync, runs an openssh daemon, and uses an insecure, authorized_key ala Vagrant. This is later used to upload cookbook test data.

The venerable `/tmp` directory is avoided, due to the popularity of `tmpfs` clobbering by inits.

Finally, the driver pulls the image specified by the suite's platform section and creates a runner container named `<unique_prefix>-<suitename>`. This container bind-mounts the volumes from `chef-<version>` and `<suite-name>-data`, giving access to Chef and the test data. By default, the `pid_one_command` of the runner container is a script that sleeps in a loop, letting us `exec` our provisioner in the next phase. It can be overridden with init systems like Upstart and systemd, for testing recipes with service resources as needed.

#### List containers

```shell
$ docker ps -a
CONTAINER ID        IMAGE                                COMMAND                  CREATED              STATUS              PORTS               NAMES
3489588d4470        6e1b03ab46-default-centos-7:latest   "sh -c 'trap exit ..."   About a minute ago   Up About a minute                       6e1b03ab46-default-centos-7
f678882b1575        chef/chef:current                    "true"                   About a minute ago   Created                                 chef-current
```

#### List images

```shell
$ docker images
REPOSITORY                    TAG                 IMAGE ID            CREATED              SIZE
6e1b03ab46-default-centos-7   latest              2ea1040b9c10        About a minute ago   192 MB
chef/chef                     current             01ec788610e2        6 days ago           124 MB
centos                        7                   67591570dd29        7 weeks ago          192 MB
```

### Converge phase

#### kitchen converge

```shell
$ time kitchen converge
-----> Starting Kitchen (v1.15.0)
-----> Converging <default-centos-7>...
       Creating local sandbox in /Users/someara/.dokken/sandbox/6e1b03ab46-default-centos-7
       Preparing dna.json
       Preparing current project directory as a cookbook
       Removing non-cookbook files before transfer
       Preparing validation.pem
       Preparing client.rb
Starting Chef Infra Client, version 16.10.8
Creating a new client identity for default-centos-7 using the validator key.
resolving cookbooks for run list: ["hello_dokken::default"]
Synchronizing Cookbooks:
  - hello_dokken (0.1.0)
Installing Cookbook Gems:
Compiling Cookbooks...
Converging 1 resources
Recipe: hello_dokken::default
  * file[/hello] action create
    - create new file /hello
    - update content in file /hello from none to 2d6944
    --- /hello    2017-02-08 04:23:01.780659287 +0000
    +++ /.chef-hello20170208-41-105f1ha    2017-02-08 04:23:01.780659287 +0000
    @@ -1 +1,2 @@
    +hello\n
    - change mode from '' to '0644'
    - change owner from '' to 'root'
    - change group from '' to 'root'

Running handlers:
Running handlers complete
Chef Client finished, 1/1 resources updated in 01 seconds
       Finished converging <default-centos-7> (0m2.61s).
-----> Kitchen is finished. (0m3.46s)

real    0m3.887s
user    0m1.080s
sys    0m0.210s
```

The `kitchen-converge` phase of the kitchen run uses the provisioner to upload cookbooks through the data container, then execs `chef-client` in the runner container. It does NOT install Chef Infra Client, as it has already been mounted by the driver. The transport then commits the runner container, creating an image that only contains the changes made by Chef.

#### List containers

```shell
$ docker ps -a
CONTAINER ID        IMAGE                          COMMAND                  CREATED             STATUS              PORTS                   NAMES
c153dfd8e53d        e9fa5d3a0d0e                   "sh -c 'trap exit 0 S"   9 minutes ago       Up 9 minutes                                default-centos-7
32c42fba4a8c        someara/kitchen-cache:latest   "/usr/sbin/sshd -D -p"   9 minutes ago       Up 9 minutes        0.0.0.0:32846->22/tcp   default-centos-7-data
7e327add6bf2        chef/chef:12.5.1               "true"                   17 minutes ago      Created                                     chef-12.5.1
```

#### List images

```shell
$ docker images
REPOSITORY              TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
default-centos-7        latest              ec1d208d77cd        8 minutes ago       172.3 MB
someara/kitchen-cache   latest              abbdb063dff1        2 weeks ago         300.8 MB
chef/chef               12.5.1              86245605bbe3        4 weeks ago         168.1 MB
centos                  7                   e9fa5d3a0d0e        6 weeks ago         172.3 MB
```

#### Diff container

```shell
$ docker diff default-centos-7
A /hello
C /opt
A /opt/chef
A /opt/kitchen
C /run
A /run/mount
A /run/mount/utab
C /tmp
C /var/lib/rpm/.dbenv.lock
C /var/lib/rpm/__db.001
C /var/lib/rpm/__db.002
C /var/lib/rpm/__db.003
```

### Verify phase

#### kitchen verify

```shell
$ time kitchen verify
-----> Starting Kitchen (v1.15.0)
-----> Setting up <default-centos-7>...
       Finished setting up <default-centos-7> (0m0.00s).
-----> Verifying <default-centos-7>...
       Loaded

Target:  docker://84def4c49ce3703e42ac2be8a95c672d561c052520ca90788d42bbdb94e7cc6f


  File /hello
     ✔  should be file
     ✔  should be mode 420
     ✔  should be owned by "root"
     ✔  should be grouped into "root"

Test Summary: 4 successful, 0 failures, 0 skipped
       Finished verifying <default-centos-7> (0m0.80s).
-----> Kitchen is finished. (0m1.99s)

real    0m2.695s
user    0m1.310s
sys    0m0.365s
```

The `kitchen-verify` phase uses the transport to run acceptance tests, verifying image state.

#### List containers

```shell
$ docker ps -a
CONTAINER ID        IMAGE                                COMMAND                  CREATED             STATUS              PORTS               NAMES
84def4c49ce3        6e1b03ab46-default-centos-7:latest   "sh -c 'trap exit ..."   6 minutes ago       Up 6 minutes                            6e1b03ab46-default-centos-7
f678882b1575        chef/chef:current                    "true"                   9 minutes ago       Created                                 chef-current
```

#### List images

```shell
$ docker images
REPOSITORY                    TAG                 IMAGE ID            CREATED             SIZE
6e1b03ab46-default-centos-7   latest              fec1a50470ed        6 minutes ago       192 MB
chef/chef                     current             01ec788610e2        6 days ago          124 MB
centos                        7                   67591570dd29        7 weeks ago         192 MB
```

### Destroy phase

#### kitchen destroy

```shell
$ kitchen destroy
-----> Starting Kitchen (v1.15.0)
-----> Destroying <default-centos-7>...
       Deleting local sandbox at /Users/someara/.dokken/sandbox/6e1b03ab46-default-centos-7
       Finished destroying <default-centos-7> (0m0.83s).
-----> Kitchen is finished. (0m1.81s)
```

#### List containers

```shell
$ docker ps -a
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
f678882b1575        chef/chef:current   "true"              10 minutes ago      Created                                 chef-current
```

#### List images

```shell
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
chef/chef           current             01ec788610e2        6 days ago          124 MB
centos              7                   67591570dd29        7 weeks ago         192 MB
```

## Advanced Configuration

Due to the nature of Docker, a handful of considerations need to be addressed.

A complete example of a non-trivial `kitchen.yml` is found in the `docker` cookbook, at <https://github.com/chef-cookbooks/docker/blob/master/kitchen.yml>

### Minimalist images

The Distros (debian, centos, etc) will typically manage an official image on the Docker Hub. They are really pushing the boundaries of minimalist images, well beyond what is typically laid to disk as part of a "base installation".

Very often, an image will come with a package manager, GNU coreutils, and that's about it. This can differ greatly from what is found in typical Vagrant and IaaS images.

Because of this, it is often necessary to "cheat" and install prerequisites
into the image before running Chef, Serverspec, or your own programs.

To help with this, the Dokken driver provides an `intermediate_instructions` directive. Here is an example from `httpd`

```yaml
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

#### Exemple use case of intermediate_instruction

A possible use case is running kitchen behind a [MITM proxy](https://en.wikipedia.org/wiki/Man-in-the-middle_attack)
If you did read the link, it's scary yes, but a reality in many corporate networks where any HTTPS connection is intercepted, when done right (morally) the proxy uses an internal Certificate Authority (CA) which is not trusted by most programs.

It's always a problem to get things accessing TLS secured servers through this kind of proxy when working in a container and here is how you can do it for Chef specifically.

Using kitchen `intemediate_instructions` and `entrypoint` you can overcome the problem in dokken in this way:

```yaml
driver:
  name: dokken
  chef_version: 16
  entrypoint: /bin/entrypoint
  intermediate_instructions:
    - RUN /usr/bin/openssl s_client -showcerts -verify 5 -connect free.fr:443 </dev/null | /usr/bin/awk '/BEGIN/,/END/{if(/BEGIN/){a++}; certs[a]=(certs[a] "\n" $0)}; END {print certs[a]}' >> /usr/local/share/ca-certificates/ca.crt && update-ca-certificates
    - RUN echo  "#!/bin/shell -ex\ncat /usr/local/share/ca-certificates/ca.crt >> /opt/chef/embedded/ssl/certs/cacert.pem\nexec \"\$@\"\n" >> /bin/entrypoint && chmod +x /bin/entrypoint
```

The code above does call a site (here free.fr, my french ISP :)) with openssl s_client and does an ugly awk parsing to extract the root CA from the chain and write it in `/usr/local/share/ca-certificate/ca.crt` and then update system certs (which makes curl, wget, and other system calls works with the proxy)

The second RUN creates an entrypoint for the container which will add the cert to Chef CA bundle and then exec whatever is passed as `pid_one_command` (see next paragraph, it does match CMD in dockerfile), this ensures once the container is created with chef volume and data volume mounted, the Chef's CA bundle accept your proxy certificate.

Caveat: multiple suites running will add the cert to the chef container each time and consume a significant amount of disk space over time. In CI systems you'll want to regularly prune containers to avoid this problem.

### Process orientation

Docker containers are process oriented rather than machine oriented. This makes life interesting when testing things not necessarily destined to run in Docker. Specifically, Chef Infra recipes that utilize the `service` resource present a problem. To overcome this, we run the container in a way that mimics a machine.

As mentioned previously, we use an infinite loop to keep the container process from exiting. This allows us to do multiple `kitchen converge` and `kitchen login` operations without needing to commit a layer and start a new container. This is fine until we need to start testing recipes that use the `service` resource.

The default `pid_one_command` is `'sh -c "trap exit 0 SIGTERM; while :; do sleep 1; done"'`

If you need to use the service resource to drive Upstart or systemd, you'll need to specify the path to init. Here are more examples from `httpd`

- systemd for RHEL-7 based platforms

```yaml
platforms:
- name: centos-7
  driver:
    image: centos:7
    privileged: true
    pid_one_command: /usr/lib/systemd/systemd
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro # required by systemd

```

You can combine `intermediate_instructions` and `pid_one_command` as needed.

- Upstart for Ubuntu 12.04

```yaml
- name: ubuntu-12.04
  driver:
    image: ubuntu-upstart:12.04
    pid_one_command: /sbin/init
    intermediate_instructions:
      - RUN /usr/bin/apt-get update
      - RUN /usr/bin/apt-get install apt-transport-https
```

### Running with User Namespaces enabled

IF you are running a Docker daemon with user namespace remapping enabled you'll get errors running dokken with privileged containers.

To mitigate this, add the following to your driver definition:

```yaml
platforms:
- name: centos-7
  driver:
    image: centos:7
    privileged: true
    userns_host: true
```

This will disable user namespaces for the running container.

### Caching Downloaded Files

On Debian/Ubuntu systems, all files downloaded via it's package manager (`apt`) are stored at `/var/cache/apt/archives/`.
Therefore one may save the downloads on a different volume and therefore save time. One may even use one's own apt cache folder to save even more time.

On some versions of Ubuntu (16.04 at least), the container deletes all the downloads upon every run of `apt-get update`, so that must be disabled

- `apt` Caching on Ubuntu 16.04

```yaml
---
driver:
  name: dokken
  volumes:
  # saves the apt archieves outside of the container
  - /var/cache/apt/archives/:/var/cache/apt/archives/

platforms:
- name: ubuntu-16.04
  driver:
    image: dokken/ubuntu-16.04
    pid_one_command: /bin/systemd
    intermediate_instructions:
      # prevent APT from deleting the APT folder
      - RUN rm /etc/apt/apt.conf.d/docker-clean
```

### Chef cache

When chef converges `kitchen-dokken` populates `/opt/kitchen/` with the chef and test kitchen data required to converge. By default this directory is cleared out at the end of every run. One of the subdirectories of `/opt/kitchen/` is the chef cache directory. For cookbooks that download significant amounts of data from the network, i.e. many `remote_file` calls, this can make subsequent converges unnecessarily slow.
If you would like the chef cache to be preserved between converges add `clean_dokken_sandbox: false` to the provisioner section of `kitchen.yml`. The default value is true.

```yaml
provisioner:
  name: dokken
  clean_dokken_sandbox: false
```

### Using dokken-images

While the `intermediate_instructions` directive is a fine hack around the
minimalist image issue, it remains exactly that: A hack. If you
work on a lot of cookbooks you will find yourself copying around
boilerplate to get things working. Also, it's slow. Running
`apt-get update` and
[installing iproute2](https://github.com/someara/dokken-images/pull/13/files)
all the time is a huge bummer.

To solve this, we maintain the
[dokken-images](https://github.com/someara/dokken-images) collection
of fat images that you can find pushed to [Docker Hub](https://hub.docker.com/r/dokken/). The package list aims to make sure things like ohai
function in a reasonable way and doing a `kitchen login` yields a
useful environment for debugging. They're hosted on the Docker cloud
and are rebuilt every day to keep the package metadata fresh.

To use them, simply prefix a distro with "dokken/" in the `image`
name. Unfortunately, you'll still have to specify `pid_one_command` (for
the time being).

```yaml
- name: ubuntu-16.04
  driver:
    image: dokken/ubuntu-16.04
    pid_one_command: /bin/systemd
  run_list:
  - recipe[whatever::recipe]
```

If you have your own mirror of Docker Hub, or you are using a registry other
than Docker Hub, you can tell Dokken to always pull from a different registry
by setting `docker_registry` under `driver`:

```yaml
driver:
  docker_registry: docker.sample.com
```

If you do this, it must have access to the dokken images for the platforms you
want to test as well as the `centos` image that is used for the dynamic
testing image.

### Tmpfs on /tmp

When starting a container with an init system, it will often mount a tmpfs into `/tmp`. When this happens, it is necessary to specify a `root_path` for the verifier if using traditional Bats or Serverspec. This is due to Docker bind mounting the kitchen data before running init. This is not necessary when using Inspec.

```yaml
verifier:
  root_path: '/opt/verifier'
  sudo: false
```

### Install Chef Infra Client from current channel

Chef publishes all functioning builds to the [Docker Hub](https://hub.docker.com/r/chef/chef/tags),
including those from the "current" channel. If you wish to use pre-release versions of Chef, set your `chef_version` value to "current". If you need to test older versions of `chef-client` that are not available on docker hub as `chef/chef`, you can overwrite `chef_image` under the [driver context](https://github.com/someara/kitchen-dokken/blob/2.5.1/lib/kitchen/driver/dokken.rb#L40) to a custom image name such as `someara/chef`.

### Chef Infra Client options

It is possible to pass several extra configs to configure the chef binary and options, for example
 to use older versions that do not have the "-z" switch or to get some debug logging.

```yaml
provisioner:
  chef_binary: /opt/chef/bin/chef-solo
  chef_options: ""
  chef_log_level: debug
  chef_output_format: minimal
  profile_ruby: true
```

### Disable pulling platform Docker images

To test a locally built image without pulling it first, one can disable
pulling of platform images, which will avoid pulling images that already
exist locally.

```yaml
driver:
  name: dokken
  pull_platform_image: false
```

### Disable pulling chef Docker images

To skip the pulling of the Chef Docker image unless it doesn't exist locally:

```yaml
driver:
  name: dokken
  pull_chef_image: false
```

### Testing for Slow Resources in Cookbooks

You can enable the slow resource report at the end of the run in Chef Infra Client 17.2 or later with the `slow_resource_report` config option:

```yaml
provisioner:
  slow_resource_report: true
```

### Testing without Chef

Containers that supply a no-op binary which returns a successful exit status can be tested without requiring Chef Infra to actually converge.

```yaml
verifier:
  name: inspec

platforms:
  - name: alpine
    driver:
      image: alpine:latest
    provisioner:
      chef_binary: /bin/true
```

### Controlling container memory

By default the memory limit of the containers you run is unbound (or limited by the Docker client on OSX). If however you need to constrain the container memory allocation you can set a memory limit in bytes on the driver:

```yaml
driver:
  name: dokken
  memory_limit: 2147483648 # 2GB
```

### Adding hostname aliases

You can set the `hostname_aliases` parameter to create additional hostnames that will resolve to the container:

```yaml
driver:
  name: dokken
  hostname_aliases:
    - foo
```

### IPv6 Networking

You can set the `ipv6` parameter to enable IPv6 networking on the `dokken` Docker network. Additionally, the `ipv6_subnet` parameter can be used to determine the subnet the network should use.

```yaml
driver:
  name: dokken
  ipv6: true
  ipv6_subnet: "2001:db8:1::/64"  # "2001:db8::/32 Range reserved for documentation"
```

This parameter should be considered a global setting for all dokken containers since dokken does not update the `dokken` network once it's been created. It is *not* recommend to use this parameter within suites.

You can check to see if IPv6 is enabled on the dokken network by seeing if the following command returns `true`:

```shell
docker network inspect dokken --format='{{.EnableIPv6}}'
```

If the command returns `false`, we recommend you delete the network and allow dokken to recreate it with IPv6.

To allow IPv6 Docker networks to reach the internet IPv6 firewall rules must be set up. The simplest way to achieve this is to update Docker's `/etc/docker/daemon.json` to use the following settings. You will need to restart the docker daemon after making these changes.

```json
{
  "experimental": true,
  "ip6tables": true
}
```

Some containers require the `ip6table_filter` kernel module to be loaded on the host system or ip6tables will not dunction on the container (Centos 7 for example). To check if the module is loaded use the command

```shell
sudo lsmod | grep ip6table_filter
```

. If there is no output than the module is not loaded and should be loaded using the command

```shell
modprobe ip6table_filter
```

### Private Docker Registries

If the registry is private, you can configure the credentials that are required to authenticate the private docker registry in `creds_file` configuration.

```yaml
platforms:
  - name: centos-7
    driver:
      image: reg/centos-7
      creds_file: './creds.json'
```

And the `creds.json` file may look like this:

```json
{
   "username": "org_username",
   "password": "password",
   "email": "email@org.com",
   "serveraddress": "https://registry.org.com/"
}
```

## FAQ

### What about kitchen-docker?

We already had a thing that drives Docker, why did you make this instead of modifying that?

The current `kitchen-docker` driver ends up baking SSH, Chef, and the kitchen data
into the image. This does not. To make this work, I had to create a Driver, a Transport,
and a Provisioner that blur the traditional duties of each. The current Docker driver
can be used with Puppet, Ansible, CFEngine provisioners. This requires Chef.

See ["Kitchen-Docker or Kitchen-Dokken? Using Test Kitchen and Docker for fast cookbook testing"](https://www.chef.io/blog/kitchen-docker-or-kitchen-dokken-using-test-kitchen-and-docker-for-fast-cookbook-testing) for a more detailed comparison.

### How can I use kitchen to automatically test and publish containers?

Right now there is no `kitchen publish` mechanism. [See this issue](https://github.com/test-kitchen/test-kitchen/issues/329).

You can, however, do it manually.

```shell
cd my_cookbook ;
kitchen verify suite_name
docker stop suite_name
docker tag suite_name:latest my.computers.biz:5043/something/whatever
docker push my.computers.biz:5043/something/whatever
kitchen destroy
```
