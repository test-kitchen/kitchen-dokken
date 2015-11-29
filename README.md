kitchen-dokken
==============

[![Build Status](https://travis-ci.org/someara/kitchen-dokken.svg?branch=master)](https://travis-ci.org/someara/kitchen-dokken)

Overview
--------

This test-kitchen plugin provides a driver, transport, and provisioner
for rapid container development using Docker and Chef.

- Behold `.kitchen.yml`

```
laptop:~/src/chef-cookbooks/hello_dokken$ cat .kitchen.yml
---
driver:
  name: dokken
    chef_version: 12.5.1

transport:
  name: dokken

provisioner:
  name: dokken

platforms:
- name: centos-7
  driver:
      image: centos:7

verifier:
  root_path: '/opt/verifier'
  sudo: false

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
the `someara/chef` image from the Docker hub, then creates a volume
container named `chef-<version>`. This makes `/opt/chef` available for
mounting by other containers.

The driver then pulls the `someara/kitchen-cache` image and starts a
volume container named `<suite-name>-data`, exposing `/opt/kitchen`,
and `/opt/verifier`. This data container is the "trick" to the whole
thing. It comes with rsync pre-installed, runs an openssh daemon, and
uses a pre-installed, insecure, authorized_key ala Vagrant. This will
later be used for uploading testing data. The usual `/tmp` directory
is avoided due tmpfs clobbering.

Finally, the driver pulls the image specified by the suite's platform
section. and creates a runner container named `<suitename>`. This
container bind-mounts the volumes from `chef-<version>` and
`<suite-name>-data`, allowing access to Chef and the test data. By
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
7e327add6bf2        someara/chef:12.5.1            "true"                   3 minutes ago       Created                                     chef-12.5.1
laptop:~/src/chef-cookbooks/hello_dokken$
```

- List images

```
laptop:~/src/chef-cookbooks/hello_dokken$ docker images
REPOSITORY              TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
someara/kitchen-cache   latest              abbdb063dff1        2 weeks ago         300.8 MB
someara/chef            12.5.1              86245605bbe3        4 weeks ago         168.1 MB
centos                  7                   e9fa5d3a0d0e        6 weeks ago         172.3 MB
default-centos-7        latest              e9fa5d3a0d0e        6 weeks ago         172.3 MB
```

### Converge phase

- Converge suite
```
laptop:~/src/chef-cookbooks/hello_dokken$ time kitchen converge
-----> Starting Kitchen (v1.4.2)
-----> Converging <default-centos-7>...
       Preparing files for transfer
       Preparing dna.json
       Preparing current project directory as a cookbook
       Removing non-cookbook files before transfer
       Preparing validation.pem
       Preparing client.rb
       Transferring files to <default-centos-7>
stdout: [2015-11-29T21:43:25+00:00] INFO: Started chef-zero at chefzero://localhost:8889 with repository at /opt/kitchen, /opt/kitchen
  One version per cookbook

stdout: [2015-11-29T21:43:25+00:00] INFO: Forking chef instance to converge...
stdout: [2015-11-29T21:43:25+00:00] INFO: *** Chef 12.5.1 ***
stdout: [2015-11-29T21:43:25+00:00] INFO: Chef-client pid: 30
stdout: [2015-11-29T21:43:25+00:00] INFO: Client key /opt/kitchen/client.pem is not present - registering
stdout: [2015-11-29T21:43:25+00:00] INFO: HTTP Request Returned 404 Not Found: Object not found: chefzero://localhost:8889/nodes/default-centos-7
stdout: [2015-11-29T21:43:25+00:00] INFO: Setting the run_list to ["recipe[hello_dokken::default]"] from CLI options
stdout: [2015-11-29T21:43:25+00:00] INFO: Run List is [recipe[hello_dokken::default]]
stdout: [2015-11-29T21:43:25+00:00] INFO: Run List expands to [hello_dokken::default]
stdout: [2015-11-29T21:43:25+00:00] INFO: Starting Chef Run for default-centos-7
stdout: [2015-11-29T21:43:25+00:00] INFO: Running start handlers
stdout: [2015-11-29T21:43:25+00:00] INFO: Start handlers complete.
stdout: [2015-11-29T21:43:25+00:00] INFO: HTTP Request Returned 404 Not Found: Object not found:
stdout: [2015-11-29T21:43:25+00:00] INFO: Loading cookbooks [hello_dokken@0.1.0]
stdout: [2015-11-29T21:43:25+00:00] INFO: Storing updated cookbooks/hello_dokken/README.md in the cache.
stdout: [2015-11-29T21:43:25+00:00] INFO: Storing updated cookbooks/hello_dokken/metadata.rb in the cache.
stdout: [2015-11-29T21:43:25+00:00] INFO: Storing updated cookbooks/hello_dokken/recipes/default.rb in the cache.
stdout: [2015-11-29T21:43:25+00:00] INFO: Processing file[/hello] action create (hello_dokken::default line 1)
stdout: [2015-11-29T21:43:25+00:00] INFO: file[/hello] created file /hello
stdout: [2015-11-29T21:43:26+00:00] INFO: file[/hello] updated file contents /hello
stdout: [2015-11-29T21:43:26+00:00] INFO: file[/hello] owner changed to 0
stdout: [2015-11-29T21:43:26+00:00] INFO: file[/hello] group changed to 0
stdout: [2015-11-29T21:43:26+00:00] INFO: file[/hello] mode changed to 644
stdout: [2015-11-29T21:43:26+00:00] INFO: Chef Run complete in 0.048119366 seconds
stdout: [2015-11-29T21:43:26+00:00] INFO: Running report handlers
stdout: [2015-11-29T21:43:26+00:00] INFO: Report handlers complete
       Finished converging <default-centos-7> (0m6.89s).
-----> Kitchen is finished. (0m7.03s)

real	0m7.602s
user	0m0.717s
sys	0m0.114s
```

The `kitchen-converge` phase of the kitchen run uses the provisioner
to upload cookbooks through the data container, then runs
`chef-client` in the runner container. It does NOT install Chef, as it
is has already mounted by the driver. The transport then commits the
runner container, creating an image the only containers the changes
made by Chef.

- List containers
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker ps -a
CONTAINER ID        IMAGE                          COMMAND                  CREATED             STATUS              PORTS                   NAMES
c153dfd8e53d        e9fa5d3a0d0e                   "sh -c 'trap exit 0 S"   9 minutes ago       Up 9 minutes                                default-centos-7
32c42fba4a8c        someara/kitchen-cache:latest   "/usr/sbin/sshd -D -p"   9 minutes ago       Up 9 minutes        0.0.0.0:32846->22/tcp   default-centos-7-data
7e327add6bf2        someara/chef:12.5.1            "true"                   17 minutes ago      Created                                     chef-12.5.1
```

- List images
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker images
REPOSITORY              TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
default-centos-7        latest              ec1d208d77cd        8 minutes ago       172.3 MB
someara/kitchen-cache   latest              abbdb063dff1        2 weeks ago         300.8 MB
someara/chef            12.5.1              86245605bbe3        4 weeks ago         168.1 MB
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
-----> Starting Kitchen (v1.4.2)
-----> Setting up <default-centos-7>...
       Finished setting up <default-centos-7> (0m0.00s).
-----> Verifying <default-centos-7>...
       Preparing files for transfer
stdout: -----> Installing Busser (busser)
stdout: Successfully installed thor-0.19.0
Successfully installed busser-0.7.1
2 gems installed
stdout: -----> Setting up Busser
stdout:        Creating BUSSER_ROOT in /opt/verifier
stdout:        Creating busser binstub
stdout:        Installing Busser plugins: busser-serverspec
stdout:        Plugin serverspec installed (version 0.5.7)
stdout: -----> Running postinstall for serverspec plugin
stdout:        Suite path directory /opt/verifier/suites does not exist, skipping.
       Transferring files to <default-centos-7>
stdout: -----> Running serverspec test suite
stdout: -----> Installing Serverspec..
stdout: -----> serverspec installed (version 2.24.3)
stdout: /opt/chef/embedded/bin/ruby -I/opt/verifier/suites/serverspec -I/opt/verifier/gems/gems/rspec-support-3.4.1/lib:/opt/verifier/gems/gems/rspec-core-3.4.1/lib /opt/chef/embedded/bin/rspec --pattern /opt/verifier/suites/serverspec/\*\*/\*_spec.rb --color --format documentation --default-path /opt/verifier/suites/serverspec
stdout:
stdout: File "/hello"
stdout:   should be file
stdout:   should be mode 644
stdout:   should be owned by "root"
stdout:   should be grouped into "root"
stdout:
Finished in 0.04909 seconds (files took 0.31393 seconds to load)
4 examples, 0 failures
stdout:
       Finished verifying <default-centos-7> (0m24.53s).
-----> Kitchen is finished. (0m24.74s)
laptop:~/src/chef-cookbooks/hello_dokken$
```

The `kitchen-verify` phase uses the transport to run integration tests and verify image state.

- List containers
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker ps -a
CONTAINER ID        IMAGE                          COMMAND                  CREATED             STATUS              PORTS                   NAMES
c153dfd8e53d        e9fa5d3a0d0e                   "sh -c 'trap exit 0 S"   15 minutes ago      Up 15 minutes                               default-centos-7
32c42fba4a8c        someara/kitchen-cache:latest   "/usr/sbin/sshd -D -p"   15 minutes ago      Up 15 minutes       0.0.0.0:32846->22/tcp   default-centos-7-data
7e327add6bf2        someara/chef:12.5.1            "true"                   24 minutes ago      Created                                     chef-12.5.1
```

- List images
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker images
REPOSITORY              TAG                 IMAGE ID            CREATED              VIRTUAL SIZE
default-centos-7        latest              bad9650b4d20        About a minute ago   175.3 MB
someara/kitchen-cache   latest              abbdb063dff1        2 weeks ago          300.8 MB
someara/chef            12.5.1              86245605bbe3        4 weeks ago          168.1 MB
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
7e327add6bf2        someara/chef:12.5.1   "true"              26 minutes ago      Created                                 chef-12.5.1
```

- List images
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker images
REPOSITORY              TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
someara/kitchen-cache   latest              abbdb063dff1        2 weeks ago         300.8 MB
someara/chef            12.5.1              86245605bbe3        4 weeks ago         168.1 MB
centos                  7                   e9fa5d3a0d0e        6 weeks ago         172.3 MB
```

README work in progress
=======================
