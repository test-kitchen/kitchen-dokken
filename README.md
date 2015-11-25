kitchen-dokken
==============

[![Build Status](https://travis-ci.org/chef-cookbooks/docker.svg?branch=master)](https://travis-ci.org/chef-cookbooks/docker) 


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

- List suites
```
laptop:~/src/chef-cookbooks/hello_dokken$ kitchen list
Instance          Driver  Provisioner  Verifier  Transport  Last
Action
default-centos-7  Dokken  Dokken       Busser    Dokken     Converged
```

- Converge suite
```
laptop:~/src/chef-cookbooks/hello_dokken$ kitchen converge
-----> Starting Kitchen (v1.4.2)
-----> Creating <default-centos-7>...
       Finished creating <default-centos-7> (0m4.47s).
-----> Converging <default-centos-7>...
       Preparing files for transfer
       Preparing dna.json
       Preparing current project directory as a cookbook
       Removing non-cookbook files before transfer
       Preparing validation.pem
       Preparing client.rb
       Transferring files to <default-centos-7>
stdout: [2015-11-25T04:11:32+00:00] INFO: Started chef-zero at chefzero://localhost:8889 with repository at /opt/kitchen, /opt/kitchen
  One version per cookbook

stdout: [2015-11-25T04:11:32+00:00] INFO: Forking chef instance to converge...
stdout: [2015-11-25T04:11:32+00:00] INFO: *** Chef 12.5.1 ***
stdout: [2015-11-25T04:11:32+00:00] INFO: Chef-client pid: 19
stdout: [2015-11-25T04:11:33+00:00] INFO: Client key /opt/kitchen/client.pem is not present - registering
stdout: [2015-11-25T04:11:33+00:00] INFO: HTTP Request Returned 404 Not Found: Object not found: chefzero://localhost:8889/nodes/default-centos-7
stdout: [2015-11-25T04:11:33+00:00] INFO: Setting the run_list to ["recipe[hello_dokken::default]"] from CLI options
stdout: [2015-11-25T04:11:33+00:00] INFO: Run List is [recipe[hello_dokken::default]]
stdout: [2015-11-25T04:11:33+00:00] INFO: Run List expands to [hello_dokken::default]
stdout: [2015-11-25T04:11:33+00:00] INFO: Starting Chef Run for default-centos-7
stdout: [2015-11-25T04:11:33+00:00] INFO: Running start handlers
stdout: [2015-11-25T04:11:33+00:00] INFO: Start handlers complete.
stdout: [2015-11-25T04:11:33+00:00] INFO: HTTP Request Returned 404 Not Found: Object not found:
stdout: [2015-11-25T04:11:33+00:00] INFO: Loading cookbooks [hello_dokken@0.1.0]
stdout: [2015-11-25T04:11:33+00:00] INFO: Storing updated cookbooks/hello_dokken/README.md in the cache.
stdout: [2015-11-25T04:11:33+00:00] INFO: Storing updated cookbooks/hello_dokken/metadata.rb in the cache.
stdout: [2015-11-25T04:11:33+00:00] INFO: Storing updated cookbooks/hello_dokken/recipes/default.rb in the cache.
stdout: [2015-11-25T04:11:33+00:00] INFO: Processing file[/hello] action create (hello_dokken::default line 1)
stdout: [2015-11-25T04:11:33+00:00] INFO: file[/hello] created file /hello
stdout: [2015-11-25T04:11:33+00:00] INFO: file[/hello] updated file contents /hello
stdout: [2015-11-25T04:11:33+00:00] INFO: file[/hello] owner changed to 0
stdout: [2015-11-25T04:11:33+00:00] INFO: file[/hello] group changed to 0
stdout: [2015-11-25T04:11:33+00:00] INFO: file[/hello] mode changed to 644
stdout: [2015-11-25T04:11:33+00:00] INFO: Chef Run complete in 0.048210571 seconds
stdout: [2015-11-25T04:11:33+00:00] INFO: Running report handlers
stdout: [2015-11-25T04:11:33+00:00] INFO: Report handlers complete
       Finished converging <default-centos-7> (0m6.88s).
-----> Kitchen is finished. (0m11.52s)

real	0m12.199s
user	0m0.915s
sys	0m0.187s
```

- Verify suite
```
laptop:~/src/chef-cookbooks/hello_dokken$ kitchen verify
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
Finished in 0.0482 seconds (files took 0.30965 seconds to load)
4 examples, 0 failures
stdout:
       Finished verifying <default-centos-7> (0m24.54s).
-----> Kitchen is finished. (0m24.75s)

real	0m25.520s
user	0m0.944s
sys	0m0.195s
```

- Examine container
```
laptop:~/src/chef-cookbooks/hello_dokken$ docker diff default-centos-7
A /[
A /]
A /hello
C /run
A /run/mount
A /run/mount/utab
C /opt
A /opt/chef
A /opt/kitchen
A /opt/verifier
laptop:~/src/chef-cookbooks/hello_dokken$
```

- Act impressed
```
Say to yourself, "Wow, that was fast! I love how the resulting
container only contains the changes Chef made, and not the tooling and
test data!"
```
