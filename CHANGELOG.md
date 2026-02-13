# Dokken Changelog

## [2.22.2](https://github.com/test-kitchen/kitchen-dokken/compare/v2.22.1...v2.22.2) (2026-02-13)


### Bug Fixes

* Allow Ruby 3.1 ([#376](https://github.com/test-kitchen/kitchen-dokken/issues/376)) ([b66d934](https://github.com/test-kitchen/kitchen-dokken/commit/b66d934d63e83f36ab841b45f0988e6205e2c37a))

## [2.22.1](https://github.com/test-kitchen/kitchen-dokken/compare/v2.22.0...v2.22.1) (2026-01-22)


### Bug Fixes

* bump dep for tk4 support and add kitchen-omnibus-chef dep ([#374](https://github.com/test-kitchen/kitchen-dokken/issues/374)) ([0aed12d](https://github.com/test-kitchen/kitchen-dokken/commit/0aed12de9d24f80dabc59d907df7566730212753))

## [2.22.0](https://github.com/test-kitchen/kitchen-dokken/compare/v2.21.4...v2.22.0) (2025-12-15)


### Features

* **ssh:** Add data_ssh_port configuration for fixed SSH port binding ([#362](https://github.com/test-kitchen/kitchen-dokken/issues/362)) ([03ed4cf](https://github.com/test-kitchen/kitchen-dokken/commit/03ed4cf8ef535f318f53decfa0c2b050335d7e81))

## [2.21.4](https://github.com/test-kitchen/kitchen-dokken/compare/v2.21.3...v2.21.4) (2025-12-15)


### Bug Fixes

* Cmd must be a slice/array of strings for modern Docker ([#368](https://github.com/test-kitchen/kitchen-dokken/issues/368)) ([9e2e819](https://github.com/test-kitchen/kitchen-dokken/commit/9e2e8191e345e5108dd7f417dc9245ebf49aa0b8))

## [2.21.3](https://github.com/test-kitchen/kitchen-dokken/compare/v2.21.2...v2.21.3) (2025-11-29)


### Bug Fixes

* fix SSH with with PAM ([#363](https://github.com/test-kitchen/kitchen-dokken/issues/363)) ([03f67eb](https://github.com/test-kitchen/kitchen-dokken/commit/03f67ebfb2e966d43bc34d5bea8d26adbab88113))

## [2.21.2](https://github.com/test-kitchen/kitchen-dokken/compare/v2.21.1...v2.21.2) (2025-11-11)


### Bug Fixes

* **dns:** Fix DNS configuration ignored on custom Docker networks ([#359](https://github.com/test-kitchen/kitchen-dokken/issues/359)) ([ea7ccd4](https://github.com/test-kitchen/kitchen-dokken/commit/ea7ccd44edb2df687eece49094938f8adc8e5014))

## [2.21.1](https://github.com/test-kitchen/kitchen-dokken/compare/v2.21.0...v2.21.1) (2025-11-03)


### Bug Fixes

* Use configured host URL when fetching docker information ([#321](https://github.com/test-kitchen/kitchen-dokken/issues/321)) ([#323](https://github.com/test-kitchen/kitchen-dokken/issues/323)) ([31e0468](https://github.com/test-kitchen/kitchen-dokken/commit/31e0468b7c7569c34abe366adf5e938f98e0e694))
* Use JSON string of OCI platform instead of os/arch string ([#356](https://github.com/test-kitchen/kitchen-dokken/issues/356)) ([#357](https://github.com/test-kitchen/kitchen-dokken/issues/357)) ([e565b46](https://github.com/test-kitchen/kitchen-dokken/commit/e565b469ab5644fe6509d7bd3843b2d438dae584))

## [2.21.0](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.8...v2.21.0) (2025-08-16)


### Features

* Require Ruby 3.2 or later + misc cleanup ([#353](https://github.com/test-kitchen/kitchen-dokken/issues/353)) ([64db987](https://github.com/test-kitchen/kitchen-dokken/commit/64db98739c2a972b14b20fccc64a79897561daf3))


### Bug Fixes

* Chef license ([#348](https://github.com/test-kitchen/kitchen-dokken/issues/348)) ([0b751c3](https://github.com/test-kitchen/kitchen-dokken/commit/0b751c334be5ff677a632be8d8623b63157ee0fb))

## [2.20.8](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.7...v2.20.8) (2025-07-08)


### Bug Fixes

* provisioner root_path config option ([#345](https://github.com/test-kitchen/kitchen-dokken/issues/345)) ([843c639](https://github.com/test-kitchen/kitchen-dokken/commit/843c63917133df399f509461bbbf8cd5b8505ceb))

## [2.20.7](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.6...v2.20.7) (2024-10-23)


### Bug Fixes

* Use default registry credentials when they are set ([#317](https://github.com/test-kitchen/kitchen-dokken/issues/317)) ([5e7f3e6](https://github.com/test-kitchen/kitchen-dokken/commit/5e7f3e65dad826114574844fe77710ea27a359e1))

## [2.20.6](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.5...v2.20.6) (2024-07-01)


### Bug Fixes

* Switch to using AlmaLinux 9 for the data container ([#329](https://github.com/test-kitchen/kitchen-dokken/issues/329)) ([955040e](https://github.com/test-kitchen/kitchen-dokken/commit/955040efdbe2c2e6e01797f59fb657313aceb86f))

## [2.20.5](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.4...v2.20.5) (2024-06-19)


### Bug Fixes

* update release please configs ([#326](https://github.com/test-kitchen/kitchen-dokken/issues/326)) ([a407bcc](https://github.com/test-kitchen/kitchen-dokken/commit/a407bccf7c45beb0d8effb4a13ce1d0ccb50f866))

## [2.20.4](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.3...v2.20.4) (2024-04-02)


### Miscellaneous Chores

* release 2.20.4 ([#320](https://github.com/test-kitchen/kitchen-dokken/issues/320)) ([054f2cf](https://github.com/test-kitchen/kitchen-dokken/commit/054f2cf175f515707535f5e6446327d7563b4244))

## [2.20.3](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.2...v2.20.3) (2023-11-28)


### Bug Fixes

* Published package name ([#313](https://github.com/test-kitchen/kitchen-dokken/issues/313)) ([57a7498](https://github.com/test-kitchen/kitchen-dokken/commit/57a74987f3c093073b09e49b05258a4b7ea0595f))

## [2.20.2](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.1...v2.20.2) (2023-11-27)


### Bug Fixes

* Update renovate config ([#310](https://github.com/test-kitchen/kitchen-dokken/issues/310)) ([db1e793](https://github.com/test-kitchen/kitchen-dokken/commit/db1e79311e477880c60fd2c83a121a8610d4e2d0))

## [2.20.1](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.0...v2.20.1) (2023-11-25)


### Bug Fixes

* Avoid mutating config to fix concurrent execution ([#279](https://github.com/test-kitchen/kitchen-dokken/issues/279)) ([116ed4a](https://github.com/test-kitchen/kitchen-dokken/commit/116ed4a64fd292523a278636ce92b430ae7560f3))
* do not set network aliases for host or bridge networks ([#295](https://github.com/test-kitchen/kitchen-dokken/issues/295)) ([02e6f23](https://github.com/test-kitchen/kitchen-dokken/commit/02e6f235de4cc43cfd9dbe9ddede0c5b6684804f))

## [2.20.0](https://github.com/test-kitchen/kitchen-dokken/compare/v2.19.1...v2.20.0) (2023-11-25)


### Features

* add support for running dokken in a container ([#281](https://github.com/test-kitchen/kitchen-dokken/issues/281)) ([bb38aca](https://github.com/test-kitchen/kitchen-dokken/commit/bb38aca9c062bc42094d1fb89fc67f3fdb9c5ba0))
* use Docker credential helpers to get auth ([#287](https://github.com/test-kitchen/kitchen-dokken/issues/287)) ([d1ba01e](https://github.com/test-kitchen/kitchen-dokken/commit/d1ba01e08e01fdc7d4f3c5cc06242578d6f3957e))


### Bug Fixes

* **CI:** Update workflows ([#303](https://github.com/test-kitchen/kitchen-dokken/issues/303)) ([a7b4535](https://github.com/test-kitchen/kitchen-dokken/commit/a7b4535b99829f813cd3848ab3a1842b8d6c6f8c))

## 2.19.1 (2023-02-07)

- Fix login command for Podman [@jmauro](https://github.com/jmauro)

## 2.19.0 (2022-12-27)

- Drop support for EOL Ruby 2.5 and 2.6 [@tas50](https://github.com/tas50)
- Fix the homepage in the gemspec [@tas50](https://github.com/tas50)
- Restore the attempt to read config.json for registry auth [@ashiqueps](https://github.com/ashiqueps)

## 2.18.0 (2022-12-22)

- Allow a user to specify a specific platform/architecture to use [@nrocco](https://github.com/nrocco)

## 2.17.4 (2022-12-20)

- Add option to run container with --cgroupns=host [@drewhammond](https://github.com/drewhammond)

## 2.17.3 (2022-07-20)

- check if ~/.docker/config.json file exists [@evandam](https://github.com/evandam)

## 2.17.2 (2022-06-16)

- Attempt to read ~/.docker/config.json for registry auths [@evandam](https://github.com/evandam)

## 2.17.1 (2022-06-09)

- Updated the Podman documentation [@damacus](https://github.com/damacus)
- Added integration tests [@damacus](https://github.com/damacus)
- Updated the chefsyle requirement

## 2.17.0 (2021-12-01)

- Added authentication for private registries [@ashiqueps](https://github.com/ashiqueps)

## 2.16.0 (2021-10-23)

- Updates transport for color output with Kitchen::Logger [@collinmcneese](https://github.com/collinmcneese)

## 2.15.0 (2021-10-21)

- Add support for Docker Desktop on Windows [@jakauppila](https://github.com/jakauppila)

## 2.14.0 (2021-07-02)

- Support Test Kitchen 3.0

## 2.13.0 (2021-06-11)

- Add support for running the slow resource report in Chef Infra Client 17.2+ with a new `slow_resource_config` option in the provisioner
- Add the ability to set hostname aliases with a new `hostname_aliases` config in the driver [@npmeyer](https://github.com/npmeyer)
- Fix execution failures on Windows [@jakauppila](https://github.com/jakauppila)
- Fix failures when running on Podman [@tomhughes](https://github.com/tomhughes)

## 2.12.1 (2021-03-01)

- Further improvements for using `docker_registry` to use a Docker Registry other than DockerHub [@jaymzh](https://github.com/jaymzh)

## 2.12.0 (2021-02-23)

- Add a new `docker_registry` config option for specifying customer docker registry URLs [@jaymzh](https://github.com/jaymzh)

## 2.11.2 (2020-12-07)

- Resolve failures when using docker-api 2.x gem

## 2.11.1 (2020-10-19)

- When checking if a port is open consider it closed if the network is down or otherwise unreachable

## 2.11.0 (2020-09-14)

- Allow docker-api gem version 2.0, which works with newer docker API releases and is Ruby 2.7 compatible

## 2.10.0 (2020-07-14)

- Added a new `memory_limit` config to set memory limits on the container. Thanks `@shanethehat`

## 2.9.1 (2020-07-14)

- Add docs for internal CA and MITM proxy Thanks `@Tensibai`
- Fix using `multiple_converge`. Thanks `@ramereth`

## 2.9.0 (2020-05-06)

- Add a new provisioning configuration `clean_dokken_sandbox` to allow not cleaning up the Chef Infra and Test Kitchen files between converges to speed up repeatedly converging systems. This defaults to true which maintains the existing behavior. Thanks `@chrisUsick`

## 2.8.2 (2020-03-10)

- Use `/opt/chef/bin/chef-client` not `/opt/chef/embedded/bin/chef-client` by default.

## 2.8.1 (2019-12-12)

- Correct container env arg (env -> Env) to match driver config

## 2.8.0 (2019-10-16)

- Set CI and TEST_KITCHEN environment variables to match other Test Kitchen drivers

## 2.7.0 (2019-05-29)

- Add the ability to disable user namespace mode when running privileged containers with a new `userns_host` config option. See the readme for details.
- Added a new option `pull_chef_image` (true/false) to control force pulling the chef image on each run to check for newer images. This now defaults to true so that testing on latest and current always actually means latest and current.

## 2.6.9 (2019-05-23)

- Support Chef Infra Client 15+ license acceptance. If the license has been accepted on your local workstation it will be passed through the Chef Infra installation. The license can also be set via the `chef_license` configuration property. See <https://docs.chef.io/chef_license_accept.html> for more details.
- Add a new config option `pull_platform_image` (true/false) which allows you to disable pulling the platform image on every dokken converge/test. This is particularly useful for local image testing.

## 2.6.8 (2019-03-19)

- Loosen the Test Kitchen dependency to allow this plugin to be used with the upcoming Test Kitchen 2.0 release
- Added a Rakefile to make it easier to ship build/install/release the gem
- Various readme improvements to clarify how to use the plugin
- Fix terminal size issue when using kitchen login
- Fail with a friendly warning if docker can't be found

## 2.6.7 (2018-03-05)

- Fix a potential race condition that may have led to the error 'Did not find config file: /opt/kitchen/client.rb'

## 2.6.6

- Improving the error message handling with intermediate builder
- README updates

## 2.6.5

- Fixing cleanup_sandbox bug. Method from test-kitchen was causing the mount to break. Replaced it with one that globs.

## 2.6.4

- Fixing pull_image method to check for new id

## 2.6.3

- tmpfs support

## 2.6.2

- Removing NotFoundError from with_retries method

## 2.6.1

- bugfix issue #118 - Ensuring sandbox cleanup on local docker hosts

## 2.6.0

- Support for testing without provisioner converging
- entrypoint config

## 2.5.1

- re-adding boot2docker detection

## 2.5.0

- Adding support for exposing ports.
- Port syntax matches docker-compose

  ```yaml
   driver:
     hostname: example.com
     ports: "1234"
  ```

  ...or something like

  ```yaml
   driver:
     hostname: example.com
     ports:
       - '1234'
       - '4321:4321/udp'
  ```

## 2.4.3

- Using better paths for lock files

## 2.4.2

- Using lockfile gem around chef-client container and dokken network creation

## 2.4.1

- Adding NotFoundError to with_retries and beefing up rescues

## 2.4.0

- Features meant for 2.2.0, but tested properly this time.
- Initial support for clusters / inter-suite name resolution
- Dokken now creates a user-defined network named "dokken" and connects containers to it. This allows us to take advantage of the built-in DNS server that in Docker 1.10 and later.

  ```yaml
   driver:
     hostname: example.com
  ```

## 2.3.1

- Actually doing the things in 2.3.0

## 2.3.0

- Reverting 2.2.x bits to 2.1.x. to restore stability to users.
- That'll teach me to push gems at odd hours.

## 2.2.4

- bugfix: Only placing runner containers in user-defined network

## 2.2.3

- bugfix: Adding guard logic for already existing dokken network

## 2.2.2

- bugfix: Creating dokken network before chef container

## 2.2.1

- Putting chef-client container in dokken network
- casting aliases to Array

## 2.2.0

- Initial support for clusters / inter-suite name resolution
- Dokken now creates a user-defined network named "dokken" and connects containers to it. This allows us to take advantage of the built-in DNS server that in Docker 1.10 and later.

  driver: hostname: example.com

## 2.1.10

- Adding boot2docker detection

## 2.1.9

- Various fixes around remote docker host usage

## 2.1.8

- Using user specified image_prefix in instance_name

## 2.1.7

- bumping version. must have accidentally pushed a 2.1.6

## 2.1.6

- PR #107 - pass write_timeout to runner exec
- PR #110 - (fix issue #109) - Add retry feature

## 2.1.5

- Fixing (again) latest/current logic (thanks @tas50)

## 2.1.4

- Fixing up current/stable/latest nomenclature to match Chef release pipeline

## 2.1.3

- Merged a bunch of PRs
- #85 - mount default boot2docker shared folder in Windows
- #93 - fix bundler path issue, should fix issue #92
- #97 - readme: systemd requires specific mount

## 2.1.2

- Making a CHANGELOG.md
- Updated gem spec to depend on test-kitchen ~> 1.5

## 2.1.1

- Fixed busser (serverspec, etc) test data uploading

## 2.0.0

- Uses chef/chef (instead of someara/chef)

- Bind mounts data instead of uploading through kitchen-cache container when talking to a local Docker host. (most use cases)

- Renders a Dockerfile and builds dokken/kitchen-cache when talking to a remote Docker host. (DOCKER_HOST =~ /^tcp:/)

## 1.0.0

- First stable release.
- Relied on someara/chef and someara/kitchen-cache from the Docker hub.
