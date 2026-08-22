# kitchen-dokken

[![Gem Version](https://badge.fury.io/rb/kitchen-dokken.svg)](https://badge.fury.io/rb/kitchen-dokken)

Fast Chef Infra cookbook testing with Docker. `kitchen-dokken` is a
[Test Kitchen](https://kitchen.ci) plugin that converges your cookbooks inside
containers in seconds rather than minutes.

- [Why kitchen-dokken?](#why-kitchen-dokken)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [How it works](#how-it-works)
- [Configuration reference](#configuration-reference)
- [Recipes](#recipes)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [FAQ](#faq)
- [License](#license)

## Why kitchen-dokken?

Test Kitchen normally splits its work across four plugin types: a **driver**
creates the machine, a **transport** connects to it, a **provisioner** puts it
into the desired state, and a **verifier** checks the result.

`kitchen-dokken` ships the first three as one purpose-built unit. That lets it
take shortcuts no general-purpose driver can:

- **No Chef install step.** Chef Infra Client is mounted into your container
  from the official `chef/chef` image, so nothing is downloaded or installed
  per run.
- **No image commits between phases.** The container is kept alive by a
  long-running PID 1, so `converge`, `verify` and `login` all reuse it.
- **No SSH by default.** Commands run through `docker exec`, and the kitchen
  sandbox is bind-mounted straight off your disk.

The result is a feedback loop measured in seconds, on a laptop, offline.

### When *not* to use it

The trade-off for that speed is scope. `kitchen-dokken` only tests Chef Infra
cookbooks — there is no Puppet or Ansible provisioner here — and a container
is not a perfect stand-in for a full OS install. Official distro images are
extremely minimal, so you may need to install packages before your cookbook
will run at all (see [Minimalist images](#minimalist-images)).

If you need a faithful analog of a production machine and would rather not
troubleshoot missing packages, reach for
[kitchen-vagrant](https://github.com/test-kitchen/kitchen-vagrant) instead. If
you want a general-purpose Docker driver that works with other provisioners,
use [kitchen-docker](https://github.com/test-kitchen/kitchen-docker).

## Requirements

- Ruby 3.1 or later
- A reachable Docker daemon — Docker Engine, Docker Desktop, Rancher Desktop
  or [Podman](documentation/PODMAN.md)
- Test Kitchen 1.15 or later

The daemon is found via `DOCKER_HOST`, then `/var/run/docker.sock`, then
`tcp://127.0.0.1:2375`. Set `docker_host_url` to override.

## Installation

`kitchen-dokken` is bundled with
[Cinc Workstation](https://cinc.sh/start/workstation/) and with
[Chef Workstation](https://www.chef.io/downloads/tools/workstation), so if you
have either installed you already have it.

Otherwise, add it to your cookbook's `Gemfile`:

```ruby
gem "kitchen-dokken"
```

or install the gem directly:

```shell
gem install kitchen-dokken
```

The examples below use Cinc. Everything works identically with Chef Infra
Client — see [Using Cinc](#using-cinc) and [Using with Chef](#using-with-chef).

## Quick start

Create a `kitchen.yml` in your cookbook:

```yaml
---
driver:
  name: dokken
  chef_version: latest

transport:
  name: dokken

provisioner:
  name: dokken
  product_name: cinc

verifier:
  name: inspec

platforms:
  - name: almalinux-9
    driver:
      image: dokken/almalinux-9
      pid_one_command: /usr/lib/systemd/systemd

  - name: ubuntu-24.04
    driver:
      image: dokken/ubuntu-24.04
      pid_one_command: /bin/systemd

suites:
  - name: default
    run_list:
      - recipe[my_cookbook::default]
```

Then run it:

```shell
kitchen test
```

Useful during development:

```shell
kitchen converge default-almalinux-9   # apply the run_list, keep the container
kitchen login default-almalinux-9      # shell into the running container
kitchen verify default-almalinux-9     # run InSpec against it
kitchen destroy                        # clean up
```

The `dokken/*` images used above come from
[dokken-images](https://github.com/test-kitchen/dokken-images): distro images
pre-loaded with the packages Ohai and a debugging session expect. See
[Using dokken-images](#using-dokken-images).

## How it works

A single `kitchen create` builds up to three containers per suite.

```text
                    ┌───────────────────────────────┐
   /opt/chef  ─────▶ │                               │
   (volume)          │   runner                      │
                     │   <hash>-default-almalinux-9  │  ◀── docker exec
   /opt/kitchen ────▶│                               │      (converge, verify,
   /opt/verifier     │   your cookbook converges     │       login)
   (bind or volume)  │   in here                     │
                     └───────────────────────────────┘
```

**The chef container** is a stopped container created from `chef/chef:<version>`.
Nothing runs in it; it exists so its `/opt/chef` can be mounted into the runner
with `VolumesFrom`. It is shared by every suite using the same Chef version, so
the image is pulled once no matter how many suites you run.

**The runner container** is where your cookbook actually converges. It is built
from a per-suite *work image* — your platform image plus any
[`intermediate_instructions`](#minimalist-images) — and kept alive by
`pid_one_command`, so the same container serves every subsequent `converge`,
`verify` and `login`.

**The data container** is only created when the Docker daemon cannot read your
local filesystem: a remote daemon, or Test Kitchen itself running inside a
container. In that case the kitchen sandbox is copied into it over SSH and
shared with the runner, instead of being bind-mounted. On a local daemon this
container is never created.

Between them you will see something like this while a suite is up:

```shell
$ docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
1f9d1cc06d-default-almalinux-9   1f9d1cc06d-default-almalinux-9:latest   Up 2 minutes
chef-latest                      chef/chef:latest                        Created
```

`kitchen destroy` removes the runner and its work image. The chef container and
the `dokken` network are deliberately left behind — they are shared, and
rebuilding them is the slow part.

## Configuration reference

### Driver

| Option | Default | Description |
| --- | --- | --- |
| `image` | derived from the platform name | Base image for the platform under test, e.g. `dokken/almalinux-9`. Falls back to `<platform>:<release>`. |
| `chef_version` | `latest` | Tag of the Chef Infra image to mount. Also accepts `current` for pre-releases, or `stable` as an alias for `latest`. |
| `chef_image` | `chef/chef` (or `cincproject/cinc`) | Repository the Chef Infra Client is mounted from. |
| `pid_one_command` | `sh -c "trap exit 0 SIGTERM; while :; do sleep 1; done"` | Command run as PID 1 to keep the container alive. Set to an init for service testing. |
| `intermediate_instructions` | none | Extra Dockerfile lines baked into the work image. See [Minimalist images](#minimalist-images). |
| `entrypoint` | none | Container `Entrypoint`. |
| `env` | none | Environment variables, as `KEY=value` strings. |
| `hostname` | `dokken` | Container hostname, also registered as a network alias. |
| `hostname_aliases` | none | Extra network aliases resolving to the container. |
| `privileged` | `false` | Run privileged. Implies host user namespaces. |
| `cap_add` / `cap_drop` | none | Linux capabilities to add or drop. |
| `security_opt` | none | Values for `--security-opt`, e.g. `seccomp=unconfined`. |
| `userns_host` | `false` | Disable user-namespace remapping for the container. |
| `user_ns_mode` | none | Docker `UsernsMode` for the container. `privileged` is only honoured when this is `host`. |
| `cgroupns_host` | `false` | Run in the host cgroup namespace. |
| `volumes` | none | Anonymous volumes, or `host:container` bind mounts. |
| `binds` | `[]` | Bind mounts, in Docker `host:container[:opts]` form. |
| `tmpfs` | `{}` | tmpfs mounts, as `/path: options` or `"/path:options"`. |
| `memory_limit` | `0` (unlimited) | Container memory limit, in bytes. |
| `ports` | none | Published ports: `container`, `host:container` or `ip:host:container`, with optional `/proto` and `low-high` ranges. |
| `network_mode` | `dokken` | Docker network to attach to. `host` and `bridge` skip alias configuration. |
| `dns` / `dns_search` | none | Nameservers and search domains for the container. |
| `links` | none | Legacy container links. |
| `ipv6` | `false` | Create the `dokken` network with IPv6 enabled. |
| `ipv6_subnet` | `2001:db8:1::/64` | Subnet used when `ipv6` is on. |
| `platform` | none | OCI platform to pin containers and images to, e.g. `linux/arm64/v8`. See [Multi-architecture testing](#multi-architecture-testing). |
| `docker_registry` | none | Registry prefix applied to every image pulled. |
| `image_prefix` | none | Prefix for the locally built work image name. |
| `pull_platform_image` | `true` | Always pull the platform image. `false` pulls only when it is missing. |
| `pull_chef_image` | `true` | Always pull the Chef Infra image. `false` pulls only when it is missing. |
| `creds_file` | none | JSON file of registry credentials. See [Private registries](#private-registries). |
| `docker_config_creds` | `true` | Read credentials from `~/.docker/config.json`. |
| `data_image` | `dokken/kitchen-cache:latest` | Image the data container is built from. |
| `data_ssh_port` | none | Fixed host port for the data container's SSH service. |
| `docker_host_url` | auto-detected | Docker daemon to talk to. |
| `read_timeout` / `write_timeout` | `3600` | Docker API timeouts, in seconds. |
| `api_retries` | `20` | How many times to retry a retryable Docker API call. |
| `docker_info` | queried from the daemon | Cached `docker info` output, used to detect the daemon's operating system. Resolved automatically; set it only to override that detection. |

### Provisioner

| Option | Default | Description |
| --- | --- | --- |
| `product_name` | `chef` | `chef` or `cinc`. See [Using Cinc](#using-cinc). |
| `product_version` | the driver's `chef_version` | Version of the client the provisioner reports running. Follows `chef_version` unless overridden. |
| `chef_license` | prompted, then remembered | License acceptance value, e.g. `accept`, `accept-silent`, `accept-no-persist`. Set it to avoid an interactive prompt in CI. |
| `chef_binary` | `/opt/chef/bin/chef-client` | Client binary to run. Defaults to the Cinc path when `product_name: cinc`. |
| `chef_options` | `" -z"` | Options passed to the client. A leading space is added if you omit it. |
| `chef_log_level` | `warn` | Value for `-l`. |
| `chef_output_format` | `doc` | Value for `-F`. |
| `root_path` | `/opt/kitchen` | Where the kitchen sandbox is mounted inside the container. |
| `clean_dokken_sandbox` | `true` | Empty the sandbox after each converge. See [Preserving the Chef cache](#preserving-the-chef-cache). |
| `profile_ruby` | `false` | Pass `--profile-ruby`. |
| `slow_resource_report` | `false` | Pass `--slow-report`. An Integer sets the threshold. Requires Chef Infra Client 17.2+. |

The provisioner inherits from `ChefInfra`, so its options — `enforce_idempotency`,
`multiple_converge`, `deprecations_as_errors`, `retry_on_exit_code`,
`max_retries`, `wait_for_retry` and the rest — work here too.

### Transport

| Option | Default | Description |
| --- | --- | --- |
| `login_command` | `docker` | Executable used by `kitchen login`. |
| `read_timeout` / `write_timeout` | `3600` | Docker API timeouts, in seconds. |
| `host_ip_override` | auto-detected | Address used to reach the data container's SSH service. Detected as `host.docker.internal` inside Docker Desktop, `localhost` against a Docker Desktop daemon, and unused otherwise. |
| `docker_host_url` | auto-detected | Docker daemon to talk to. |
| `docker_info` | queried from the daemon | Cached `docker info` output for `docker_host_url`. The driver and transport resolve this independently. |

## Recipes

### Testing services and init systems

Containers are process-oriented, not machine-oriented, which matters as soon as
a recipe uses the `service` resource. To make `systemd` work, run it as PID 1:

```yaml
platforms:
  - name: almalinux-9
    driver:
      image: dokken/almalinux-9
      privileged: true
      pid_one_command: /usr/lib/systemd/systemd
```

Older kernels or daemons may also need the host cgroup filesystem mounted in:

```yaml
      volumes:
        - /sys/fs/cgroup:/sys/fs/cgroup:ro
```

### Minimalist images

Official distro images ship a package manager, coreutils and very little else —
far less than a Vagrant box or a cloud image. You will often need to install
prerequisites before Chef, InSpec or your own programs will run.

`intermediate_instructions` adds Dockerfile lines to the per-suite work image:

```yaml
platforms:
  - name: debian-12
    driver:
      image: debian:12
      intermediate_instructions:
        - RUN /usr/bin/apt-get update
        - RUN /usr/bin/apt-get install -y apt-transport-https net-tools
```

Any valid Dockerfile instruction works. Use this as little as possible — it
runs on every work-image build, and [dokken-images](#using-dokken-images)
usually solves the same problem for free.

### Using dokken-images

[dokken-images](https://github.com/test-kitchen/dokken-images) are distro
images pre-loaded with the packages that make Ohai behave and `kitchen login`
useful. They are rebuilt daily so package metadata stays fresh. Prefix a distro
with `dokken/`:

```yaml
platforms:
  - name: ubuntu-24.04
    driver:
      image: dokken/ubuntu-24.04
      pid_one_command: /bin/systemd
```

You still need to specify `pid_one_command` yourself.

### Using Cinc

[Cinc Client](https://cinc.sh/) is the community distribution of Chef Infra
Client. Set `product_name: cinc` on the provisioner; nothing else is required:

```yaml
provisioner:
  name: dokken
  product_name: cinc
```

With that set, `kitchen-dokken` pulls
[`cincproject/cinc`](https://hub.docker.com/r/cincproject/cinc) instead of
`chef/chef`, uses a `cinc-<version>` volume container so it will not collide
with Chef Infra containers, runs `/opt/cinc/bin/cinc-client`, and skips the
Chef license prompt (Cinc is community-built and Apache-licensed).

Override `chef_image` or `chef_binary` if you need a custom Cinc image or a
non-standard install path.

### Using with Chef

The examples in this README set `product_name: cinc`. Leaving it unset, or
setting `product_name: chef`, runs Chef Infra Client instead — that is the
driver's default:

```yaml
provisioner:
  name: dokken
  product_name: chef
```

With Chef Infra Client you will need to accept the Chef licence, either by
setting `chef_license` on the provisioner or by answering the prompt. Cinc has
no such requirement.

Nothing else differs: the same driver, transport, and verifier options apply
either way.

### Using Podman

See [the Podman documentation](documentation/PODMAN.md).

### Multi-architecture testing

Set `platform` to test an architecture other than your host's. It is passed to
the daemon as an OCI platform, so emulation must be available (Docker Desktop
and `binfmt_misc` both provide it):

```yaml
platforms:
  - name: almalinux-9-arm
    driver:
      image: dokken/almalinux-9
      platform: linux/arm64/v8
```

The runner and the Chef volume container are both pinned to this platform,
since `/opt/chef` is mounted from one into the other. The data container is
not: it only serves files over SSH, and is always built for the host.

### Networking

Publish ports, add aliases and set DNS on the driver:

```yaml
driver:
  name: dokken
  hostname: web.example.com
  hostname_aliases:
    - web
    - www
  ports:
    - '8080:80'
    - '8301:8301/udp'
    - '127.0.0.1:8500:8500'
    - '9000-9002'
  dns:
    - 8.8.8.8
  dns_search:
    - example.com
```

Containers join the `dokken` network by default, which is what lets suites
resolve each other by hostname. `network_mode: host` and `network_mode: bridge`
are also supported, but skip alias registration.

#### IPv6

```yaml
driver:
  name: dokken
  ipv6: true
  ipv6_subnet: "2001:db8:1::/64"
```

This is effectively a global setting: `kitchen-dokken` does not reconfigure the
`dokken` network once it exists, so setting it per-suite will not do what you
expect. Check the current state with:

```shell
docker network inspect dokken --format='{{.EnableIPv6}}'
```

If that prints `false`, delete the network and let dokken recreate it.

For IPv6 containers to reach the internet, the daemon needs `ip6tables`
support in `/etc/docker/daemon.json` (restart the daemon afterwards):

```json
{
  "experimental": true,
  "ip6tables": true
}
```

Some images additionally need the `ip6table_filter` module loaded on the host:

```shell
sudo lsmod | grep ip6table_filter || sudo modprobe ip6table_filter
```

### Private registries

Credentials are scoped to the registry an image is pulled from, the way the
`docker` CLI scopes them. An image whose registry has no matching entry is
pulled anonymously rather than with some other registry's credentials.

By default `~/.docker/config.json` is read, so `docker login` is usually all
you need:

```json
{
  "auths": {
    "quay.io": {
      "auth": "<base64 encoded username:password>"
    }
  }
}
```

Images with no registry prefix (`almalinux:9`, `dokken/almalinux-8`) resolve to
Docker Hub and use the `https://index.docker.io/v1/` entry. `docker.io` and
`registry-1.docker.io` are accepted as Hub aliases too.

[Credential helpers](https://docs.docker.com/engine/reference/commandline/login/#credential-helpers)
work as well — `kitchen-dokken` runs `docker-credential-<helper>` on demand:

```json
{
  "credHelpers": {
    "1234-cloud-registry.example.com": "example-cloud"
  }
}
```

Set `docker_config_creds: false` to ignore the Docker config entirely and pull
anonymously.

To supply credentials directly instead, point `creds_file` at a JSON file:

```yaml
platforms:
  - name: almalinux-9
    driver:
      image: registry.example.com/almalinux-9
      creds_file: './creds.json'
```

```json
{
  "username": "org_username",
  "password": "password",
  "email": "email@org.com",
  "serveraddress": "https://registry.example.com/"
}
```

A `creds_file` takes precedence over `~/.docker/config.json`, and is used for
every registry.

### Pulling through a mirror

To route every pull through your own registry or Docker Hub mirror:

```yaml
driver:
  docker_registry: docker.example.com
```

The mirror must carry the platform images you test with, plus the
`almalinux:9` image used to build the data image.

### Remote and containerised Docker hosts

When the daemon cannot read your local filesystem, `kitchen-dokken`
automatically builds the data container and ships the sandbox to it over SSH.
This happens when `docker_host_url` is a `tcp://` URL (Docker Desktop and
Boot2Docker excepted — they share the host's files), or when Test Kitchen is
itself running inside a container.

The data container's SSH service is published on a random host port. Pin it if
you need a predictable firewall rule:

```yaml
driver:
  name: dokken
  data_ssh_port: 30000
```

When Test Kitchen is the thing running in a container, that container also has
to be able to *reach* the containers it creates. They are attached to the
`network_mode` network — `dokken` by default — and Docker will not route from
the default bridge to a user-defined network, so attach kitchen's own container
to the same one:

```shell
docker network inspect dokken >/dev/null 2>&1 || docker network create dokken

docker run --rm \
  --network dokken \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD:/workspace" -w /workspace \
  ruby:3.4 bundle exec kitchen test
```

Without it the converge fails at `Transferring files` with a connection
timeout.

### Caching downloaded packages

Package downloads can be cached outside the container. On Debian and Ubuntu,
`apt` also needs to be told to stop deleting them:

```yaml
driver:
  name: dokken
  volumes:
    - /var/cache/apt/archives/:/var/cache/apt/archives/

platforms:
  - name: ubuntu-24.04
    driver:
      image: dokken/ubuntu-24.04
      pid_one_command: /bin/systemd
      intermediate_instructions:
        - RUN rm -f /etc/apt/apt.conf.d/docker-clean
```

### Preserving the Chef cache

`/opt/kitchen` is emptied after every converge, which includes the Chef file
cache. For cookbooks that pull a lot of data with `remote_file`, keeping it
makes repeat converges much faster:

```yaml
provisioner:
  name: dokken
  clean_dokken_sandbox: false
```

### Limiting container memory

Memory is unbounded by default (or bounded by the Docker VM on macOS and
Windows):

```yaml
driver:
  name: dokken
  memory_limit: 2147483648 # 2GB
```

### tmpfs on /tmp

A container running an init system will usually mount a tmpfs over `/tmp`.
Because Docker bind-mounts the kitchen data before init starts, Bats and
Serverspec need to be pointed somewhere else. InSpec is unaffected.

```yaml
verifier:
  root_path: '/opt/verifier'
  sudo: false
```

### Chef Infra Client options

```yaml
provisioner:
  name: dokken
  chef_binary: /opt/chef/bin/chef-solo
  chef_options: ""
  chef_log_level: debug
  chef_output_format: minimal
  profile_ruby: true
  slow_resource_report: true
```

Use `chef_options: ""` for old clients that predate `-z`.

### Testing without Chef

If the image supplies a no-op binary that exits successfully, a suite can be
verified without converging at all:

```yaml
platforms:
  - name: alpine
    driver:
      image: alpine:latest
    provisioner:
      chef_binary: /bin/true
```

### Pre-release and archived Chef versions

Chef publishes every functioning build to
[Docker Hub](https://hub.docker.com/r/chef/chef/tags), including the `current`
channel:

```yaml
driver:
  chef_version: current
```

For versions not published as `chef/chef`, point `chef_image` at another
repository:

```yaml
driver:
  chef_image: someara/chef
  chef_version: 12.21.31
```

### Testing behind a TLS-intercepting proxy

Corporate networks often terminate TLS with an internal CA that containers do
not trust. `intermediate_instructions` plus `entrypoint` can install it into
both the system trust store and Chef's own bundle:

```yaml
driver:
  name: dokken
  entrypoint: /bin/entrypoint
  intermediate_instructions:
    - RUN /usr/bin/openssl s_client -showcerts -verify 5 -connect example.com:443 </dev/null | /usr/bin/awk '/BEGIN/,/END/{if(/BEGIN/){a++}; certs[a]=(certs[a] "\n" $0)}; END {print certs[a]}' >> /usr/local/share/ca-certificates/ca.crt && update-ca-certificates
    - RUN echo "#!/bin/sh -e\ncat /usr/local/share/ca-certificates/ca.crt >> /opt/chef/embedded/ssl/certs/cacert.pem\nexec \"\$@\"\n" >> /bin/entrypoint && chmod +x /bin/entrypoint
```

The first instruction extracts the root CA from a live handshake and adds it to
the system trust store. The second writes an entrypoint that appends it to
Chef's CA bundle before exec'ing `pid_one_command`.

Note that each suite adds the certificate again, which accumulates disk usage
over time. Prune regularly on CI.

A complete, non-trivial `kitchen.yml` lives in the
[`docker` cookbook](https://github.com/chef-cookbooks/docker/blob/main/kitchen.yml).

## Troubleshooting

**`could not connect to the docker host ... Is docker running?`**
The daemon is unreachable. Check `docker info`, and set `docker_host_url` if
your daemon is not at `DOCKER_HOST` or `/var/run/docker.sock`.

**The `service` resource fails, or `systemctl` reports no init system.**
Set `pid_one_command` to your init and run `privileged: true`. See
[Testing services and init systems](#testing-services-and-init-systems).

**Ohai warnings, or a missing `ip`, `ps` or `hostname` command.**
The base image is too minimal. Switch to a
[dokken-image](#using-dokken-images) or add the packages with
[`intermediate_instructions`](#minimalist-images).

**A pull from a private registry returns 401.**
Credentials are matched per registry. Confirm the registry host in your image
reference has an entry in `~/.docker/config.json`, or supply a `creds_file`.

**Changes to `intermediate_instructions` seem to be ignored.**
The work image is cached per suite. Run `kitchen destroy` for that suite to
force a rebuild.

**IPv6 settings do not take effect.**
The `dokken` network is created once and never reconfigured. See
[IPv6](#ipv6).

**Stale containers or images are piling up.**
`kitchen destroy` intentionally leaves the shared chef container and the
`dokken` network behind. Remove them by hand when you want a clean slate:

```shell
docker rm -f chef-latest
docker network rm dokken
```

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md)
for how to set up, run the unit and integration suites, and what CI checks.

## FAQ

### What about kitchen-docker?

`kitchen-docker` bakes SSH, Chef and the kitchen data into the image, and works
as a general-purpose driver with any provisioner. `kitchen-dokken` blurs the
driver, transport and provisioner roles together to avoid all of that, at the
cost of only supporting Chef Infra.

See ["Kitchen-Docker or Kitchen-Dokken?"](https://www.chef.io/blog/kitchen-docker-or-kitchen-dokken-using-test-kitchen-and-docker-for-fast-cookbook-testing)
for a longer comparison.

### Can I publish the container I just tested?

There is no `kitchen publish`
([test-kitchen#329](https://github.com/test-kitchen/test-kitchen/issues/329)),
but you can do it by hand:

```shell
kitchen verify suite_name
docker stop suite_name
docker tag suite_name:latest registry.example.com:5043/org/image
docker push registry.example.com:5043/org/image
kitchen destroy
```

### Do I have to accept the Chef license?

Yes, for Chef Infra Client. See
[the license documentation](documentation/chef_license.md). Cinc does not
require it.

## License

Apache-2.0. See [LICENSE](LICENSE).
