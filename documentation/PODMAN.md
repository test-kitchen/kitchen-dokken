# Using Kitchen Dokken with Podman

Using Dokken with podman is a little less straight forward than with Docker. The main problem is volumes are not populated when they are first created.

As per [this issue](https://github.com/test-kitchen/kitchen-dokken/issues/255), we can use lifecycle hooks to create the volume and populate it with the Chef executable before we try and start the main container.

_Note_, if you’re using a specific version of Chef, and not latest, then you need to reference the correct version in your podman create command because this breaks the automatic pulling of the correct version of the Chef Docker image by kitchen-dokken.

```yaml
---
driver:
  name: dokken
  privileged: true  # allows systemd services to start

provisioner:
  name: dokken
  login_command: podman

transport:
  name: dokken

verifier:
  name: inspec

platforms:
  # @see https://github.com/chef-cookbooks/testing_examples/blob/main/kitchen.dokken.yml
  # @see https://hub.docker.com/u/dokken
  - name: ubuntu-20.04
    driver:
      image: dokken/ubuntu-20.04
      pid_one_command: /bin/systemd
      intermediate_instructions:
        - RUN /usr/bin/apt-get update

  - name: centos-8
    driver:
      image: dokken/centos-8
      pid_one_command: /usr/lib/systemd/systemd

suites:
  - name: default
    run_list:
      - recipe[test_linux::default]
    verifier:
      inspec_tests:
        - test/integration/default
    lifecycle:
      pre_create:
        - podman create --name chef-latest --replace docker.io/chef/chef:latest sh
        - podman start chef-latest
      post_destroy:
        - podman volume prune -f
```
