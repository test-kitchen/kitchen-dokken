# Dokken Changelog

## Unreleased

* chore(deps): update googleapis/release-please-action action to v5 ([#380](https://github.com/test-kitchen/kitchen-dokken/pull/380)) ([02144ab](https://github.com/test-kitchen/kitchen-dokken/commit/02144ab))
* chore(deps): update actions/checkout action to v7 ([#386](https://github.com/test-kitchen/kitchen-dokken/pull/386)) ([0fba201](https://github.com/test-kitchen/kitchen-dokken/commit/0fba201))
* Require Ruby 3.1+ and modernize CI ([#392](https://github.com/test-kitchen/kitchen-dokken/pull/392)) ([42e0f76](https://github.com/test-kitchen/kitchen-dokken/commit/42e0f76))
* Let cookstyle decide which files to lint ([#393](https://github.com/test-kitchen/kitchen-dokken/pull/393)) ([a551a3c](https://github.com/test-kitchen/kitchen-dokken/commit/a551a3c))
* Rewrite the unit suite, document every method, fix the bugs it found ([#394](https://github.com/test-kitchen/kitchen-dokken/pull/394)) ([73150f6](https://github.com/test-kitchen/kitchen-dokken/commit/73150f6))
* Exercise the plugin directly in CI ([#395](https://github.com/test-kitchen/kitchen-dokken/pull/395)) ([c995d9b](https://github.com/test-kitchen/kitchen-dokken/commit/c995d9b))
* Docs: document the last four options and lead with Cinc ([#398](https://github.com/test-kitchen/kitchen-dokken/pull/398)) ([c13e9ba](https://github.com/test-kitchen/kitchen-dokken/commit/c13e9ba))
* Remove dependabot config in favor of renovate ([#400](https://github.com/test-kitchen/kitchen-dokken/pull/400)) ([b24f802](https://github.com/test-kitchen/kitchen-dokken/commit/b24f802))

## [2.23.3](https://github.com/test-kitchen/kitchen-dokken/compare/v2.23.2...v2.23.3) (2026-07-28)

### Bug Fixes

* scope registry credentials per registry and honor docker_config_creds ([#388](https://github.com/test-kitchen/kitchen-dokken/issues/388)) ([6e049e5](https://github.com/test-kitchen/kitchen-dokken/commit/6e049e5b85a5c1beb9c7cafd0af4a7c64195bf41))

## [2.23.2](https://github.com/test-kitchen/kitchen-dokken/compare/v2.23.1...v2.23.2) (2026-07-28)

### Bug Fixes

* keep the OCI platform variant so variant platforms work end to end ([#389](https://github.com/test-kitchen/kitchen-dokken/issues/389)) ([85c47b2](https://github.com/test-kitchen/kitchen-dokken/commit/85c47b2820b41cb70396a06cd44f9d222c7fc5bc))

## [2.23.1](https://github.com/test-kitchen/kitchen-dokken/compare/v2.23.0...v2.23.1) (2026-05-21)

### Bug Fixes

* **provisioner:** guard check_license against non-omnibus parents ([#384](https://github.com/test-kitchen/kitchen-dokken/issues/384)) ([f720705](https://github.com/test-kitchen/kitchen-dokken/commit/f7207053b781620ce922045889cf441755eee2cb)), closes [#383](https://github.com/test-kitchen/kitchen-dokken/issues/383)

## [2.23.0](https://github.com/test-kitchen/kitchen-dokken/compare/v2.22.2...v2.23.0) (2026-05-19)

### Features

* Add proper support for Cinc ([#381](https://github.com/test-kitchen/kitchen-dokken/issues/381)) ([430d65e](https://github.com/test-kitchen/kitchen-dokken/commit/430d65ec4ef6dde69a0d7c14c241b573663aa601))

## [2.22.2](https://github.com/test-kitchen/kitchen-dokken/compare/v2.22.1...v2.22.2) (2026-02-13)

### Bug Fixes

* Allow Ruby 3.1 ([#376](https://github.com/test-kitchen/kitchen-dokken/issues/376)) ([b66d934](https://github.com/test-kitchen/kitchen-dokken/commit/b66d934d63e83f36ab841b45f0988e6205e2c37a))

## [2.22.1](https://github.com/test-kitchen/kitchen-dokken/compare/v2.22.0...v2.22.1) (2026-01-22)

### Bug Fixes

* bump dep for tk4 support and add kitchen-omnibus-chef dep ([#374](https://github.com/test-kitchen/kitchen-dokken/issues/374)) ([0aed12d](https://github.com/test-kitchen/kitchen-dokken/commit/0aed12de9d24f80dabc59d907df7566730212753))

## [2.22.0](https://github.com/test-kitchen/kitchen-dokken/compare/v2.21.4...v2.22.0) (2025-12-15)

### Features

* **ssh:** Add data_ssh_port configuration for fixed SSH port binding ([#362](https://github.com/test-kitchen/kitchen-dokken/issues/362)) ([03ed4cf](https://github.com/test-kitchen/kitchen-dokken/commit/03ed4cf8ef535f318f53decfa0c2b050335d7e81))

### Other Changes

* chore(deps): update actions/checkout action to v6 ([#365](https://github.com/test-kitchen/kitchen-dokken/pull/365)) ([fde0857](https://github.com/test-kitchen/kitchen-dokken/commit/fde0857))

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

### Other Changes

* fix: correct start of data container ([#331](https://github.com/test-kitchen/kitchen-dokken/pull/331)) ([3ec6ed2](https://github.com/test-kitchen/kitchen-dokken/commit/3ec6ed2))

## [2.21.0](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.8...v2.21.0) (2025-08-16)

### Features

* Require Ruby 3.2 or later + misc cleanup ([#353](https://github.com/test-kitchen/kitchen-dokken/issues/353)) ([64db987](https://github.com/test-kitchen/kitchen-dokken/commit/64db98739c2a972b14b20fccc64a79897561daf3))


### Bug Fixes

* Chef license ([#348](https://github.com/test-kitchen/kitchen-dokken/issues/348)) ([0b751c3](https://github.com/test-kitchen/kitchen-dokken/commit/0b751c334be5ff677a632be8d8623b63157ee0fb))

### Other Changes

* chore(deps): update actions/checkout action to v5 ([#352](https://github.com/test-kitchen/kitchen-dokken/pull/352)) ([6723675](https://github.com/test-kitchen/kitchen-dokken/commit/6723675))
* chore(deps): update dependency cookstyle to v8.4.0 ([#349](https://github.com/test-kitchen/kitchen-dokken/pull/349)) ([f12d553](https://github.com/test-kitchen/kitchen-dokken/commit/f12d553))

## [2.20.8](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.7...v2.20.8) (2025-07-08)

### Bug Fixes

* provisioner root_path config option ([#345](https://github.com/test-kitchen/kitchen-dokken/issues/345)) ([843c639](https://github.com/test-kitchen/kitchen-dokken/commit/843c63917133df399f509461bbbf8cd5b8505ceb))

### Other Changes

* Fix minor typos ([#336](https://github.com/test-kitchen/kitchen-dokken/pull/336)) ([f783577](https://github.com/test-kitchen/kitchen-dokken/commit/f783577))
* Require Ruby 3.1 or later ([#337](https://github.com/test-kitchen/kitchen-dokken/pull/337)) ([c79664d](https://github.com/test-kitchen/kitchen-dokken/commit/c79664d))
* chore(deps-dev): update cookstyle requirement from 7.32.8 to 8.2.1 ([#344](https://github.com/test-kitchen/kitchen-dokken/pull/344)) ([a6d7563](https://github.com/test-kitchen/kitchen-dokken/commit/a6d7563))

## [2.20.7](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.6...v2.20.7) (2024-10-23)

### Bug Fixes

* Use default registry credentials when they are set ([#317](https://github.com/test-kitchen/kitchen-dokken/issues/317)) ([5e7f3e6](https://github.com/test-kitchen/kitchen-dokken/commit/5e7f3e65dad826114574844fe77710ea27a359e1))

## [2.20.6](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.5...v2.20.6) (2024-07-01)

### Bug Fixes

* Switch to using AlmaLinux 9 for the data container ([#329](https://github.com/test-kitchen/kitchen-dokken/issues/329)) ([955040e](https://github.com/test-kitchen/kitchen-dokken/commit/955040efdbe2c2e6e01797f59fb657313aceb86f))

### Other Changes

* ci: Create CODEOWNERS ([#328](https://github.com/test-kitchen/kitchen-dokken/pull/328)) ([d20fe09](https://github.com/test-kitchen/kitchen-dokken/commit/d20fe09))

## [2.20.5](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.4...v2.20.5) (2024-06-19)

### Bug Fixes

* update release please configs ([#326](https://github.com/test-kitchen/kitchen-dokken/issues/326)) ([a407bcc](https://github.com/test-kitchen/kitchen-dokken/commit/a407bccf7c45beb0d8effb4a13ce1d0ccb50f866))

## [2.20.4](https://github.com/test-kitchen/kitchen-dokken/compare/v2.20.3...v2.20.4) (2024-04-02)

### Miscellaneous Chores

* release 2.20.4 ([#320](https://github.com/test-kitchen/kitchen-dokken/issues/320)) ([054f2cf](https://github.com/test-kitchen/kitchen-dokken/commit/054f2cf175f515707535f5e6446327d7563b4244))

### Other Changes

* fix failed run exit code when clean_dokken_sandbox is false ([#319](https://github.com/test-kitchen/kitchen-dokken/pull/319)) ([1035b97](https://github.com/test-kitchen/kitchen-dokken/commit/1035b97))

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

### Other Changes

* allow to set user namespaces ([#148](https://github.com/test-kitchen/kitchen-dokken/pull/148)) ([b5e43da](https://github.com/test-kitchen/kitchen-dokken/commit/b5e43da))
* Add link checking to GitHub Actions ([#291](https://github.com/test-kitchen/kitchen-dokken/pull/291)) ([a6a49f5](https://github.com/test-kitchen/kitchen-dokken/commit/a6a49f5))
* Setup dependabot to keep GH Actions up to date ([#292](https://github.com/test-kitchen/kitchen-dokken/pull/292)) ([43f3c62](https://github.com/test-kitchen/kitchen-dokken/commit/43f3c62))
* Bump actions/checkout from 2 to 3 ([#293](https://github.com/test-kitchen/kitchen-dokken/pull/293)) ([683e618](https://github.com/test-kitchen/kitchen-dokken/commit/683e618))
* always downcase the container name ([#151](https://github.com/test-kitchen/kitchen-dokken/pull/151)) ([a1b5ec2](https://github.com/test-kitchen/kitchen-dokken/commit/a1b5ec2))
* Update update-workflows ([#297](https://github.com/test-kitchen/kitchen-dokken/pull/297)) ([4d29721](https://github.com/test-kitchen/kitchen-dokken/commit/4d29721))
* Bump actions/checkout from 3 to 4 ([#298](https://github.com/test-kitchen/kitchen-dokken/pull/298)) ([47a0d43](https://github.com/test-kitchen/kitchen-dokken/commit/47a0d43))
* Update chefstyle requirement from 2.2.2 to 2.2.3 ([#300](https://github.com/test-kitchen/kitchen-dokken/pull/300)) ([b453653](https://github.com/test-kitchen/kitchen-dokken/commit/b453653))
* Configure Renovate ([#301](https://github.com/test-kitchen/kitchen-dokken/pull/301)) ([8c25eef](https://github.com/test-kitchen/kitchen-dokken/commit/8c25eef))
* fix(lint) ignore release pleases markdown errors ([#305](https://github.com/test-kitchen/kitchen-dokken/pull/305)) ([763269a](https://github.com/test-kitchen/kitchen-dokken/commit/763269a))
* fix(lint) add another mdl ignore ([#307](https://github.com/test-kitchen/kitchen-dokken/pull/307)) ([fd5fcf9](https://github.com/test-kitchen/kitchen-dokken/commit/fd5fcf9))

## 2.19.1 (2023-02-07)

- Fix login command for Podman [@jmauro](https://github.com/jmauro)

## 2.19.0 (2022-12-27)

- Drop support for EOL Ruby 2.5 and 2.6 [@tas50](https://github.com/tas50)
- Fix the homepage in the gemspec [@tas50](https://github.com/tas50)
- Restore the attempt to read config.json for registry auth [@ashiqueps](https://github.com/ashiqueps)

* Fix the homepage URL ([b5f4a0d](https://github.com/test-kitchen/kitchen-dokken/commit/b5f4a0d))
* Rubocop fixes ([d9cb7bf](https://github.com/test-kitchen/kitchen-dokken/commit/d9cb7bf))

## 2.18.0 (2022-12-22)

- Allow a user to specify a specific platform/architecture to use [@nrocco](https://github.com/nrocco)

## 2.17.4 (2022-12-20)

- Add option to run container with --cgroupns=host [@drewhammond](https://github.com/drewhammond)

## 2.17.3 (2022-07-20)

- check if ~/.docker/config.json file exists [@evandam](https://github.com/evandam)

* check if ~/.docker/config.json exists ([#276](https://github.com/test-kitchen/kitchen-dokken/pull/276)) ([09a9bd7](https://github.com/test-kitchen/kitchen-dokken/commit/09a9bd7))
* Updated link to blog ([#274](https://github.com/test-kitchen/kitchen-dokken/pull/274)) ([4af018c](https://github.com/test-kitchen/kitchen-dokken/commit/4af018c))

## 2.17.2 (2022-06-16)

- Attempt to read ~/.docker/config.json for registry auths [@evandam](https://github.com/evandam)

## 2.17.1 (2022-06-09)

- Updated the Podman documentation [@damacus](https://github.com/damacus)
- Added integration tests [@damacus](https://github.com/damacus)
- Updated the chefsyle requirement

* Update chefstyle requirement from 2.1.2 to 2.2.0 ([#256](https://github.com/test-kitchen/kitchen-dokken/pull/256)) ([b6cbdb2](https://github.com/test-kitchen/kitchen-dokken/commit/b6cbdb2))
* Update chefstyle requirement from 2.2.0 to 2.2.2 ([#260](https://github.com/test-kitchen/kitchen-dokken/pull/260)) ([82258ff](https://github.com/test-kitchen/kitchen-dokken/commit/82258ff))
* Add integration tests ([#263](https://github.com/test-kitchen/kitchen-dokken/pull/263)) ([00f0ba2](https://github.com/test-kitchen/kitchen-dokken/commit/00f0ba2))
* Add pod man documentation ([#265](https://github.com/test-kitchen/kitchen-dokken/pull/265)) ([5f6fa14](https://github.com/test-kitchen/kitchen-dokken/commit/5f6fa14))

## 2.17.0 (2021-12-01)

- Added authentication for private registries [@ashiqueps](https://github.com/ashiqueps)

* Update chefstyle requirement from 2.1.0 to 2.1.1 ([#251](https://github.com/test-kitchen/kitchen-dokken/pull/251)) ([557cb05](https://github.com/test-kitchen/kitchen-dokken/commit/557cb05))
* Update chefstyle requirement from 2.1.1 to 2.1.2 ([#252](https://github.com/test-kitchen/kitchen-dokken/pull/252)) ([039d322](https://github.com/test-kitchen/kitchen-dokken/commit/039d322))

## 2.16.0 (2021-10-23)

- Updates transport for color output with Kitchen::Logger [@collinmcneese](https://github.com/collinmcneese)

## 2.15.0 (2021-10-21)

- Add support for Docker Desktop on Windows [@jakauppila](https://github.com/jakauppila)

* Update chefstyle requirement from 2.0.5 to 2.0.8 ([#245](https://github.com/test-kitchen/kitchen-dokken/pull/245)) ([059f275](https://github.com/test-kitchen/kitchen-dokken/commit/059f275))
* Update chefstyle requirement from 2.0.8 to 2.0.9 ([#246](https://github.com/test-kitchen/kitchen-dokken/pull/246)) ([2ade7db](https://github.com/test-kitchen/kitchen-dokken/commit/2ade7db))
* Update chefstyle requirement from 2.0.9 to 2.1.0 ([#248](https://github.com/test-kitchen/kitchen-dokken/pull/248)) ([4a444aa](https://github.com/test-kitchen/kitchen-dokken/commit/4a444aa))
* Adds detection of Docker Desktop for Dokken on Windows ([#249](https://github.com/test-kitchen/kitchen-dokken/pull/249)) ([01b64e8](https://github.com/test-kitchen/kitchen-dokken/commit/01b64e8))

## 2.14.0 (2021-07-02)

- Support Test Kitchen 3.0

* Add IPv6 Support ([#239](https://github.com/test-kitchen/kitchen-dokken/pull/239)) ([c9eb40b](https://github.com/test-kitchen/kitchen-dokken/commit/c9eb40b))
* Update chefstyle requirement from 2.0.4 to 2.0.5 ([#240](https://github.com/test-kitchen/kitchen-dokken/pull/240)) ([79db64d](https://github.com/test-kitchen/kitchen-dokken/commit/79db64d))
* Chefstyle fixes ([f13a4ba](https://github.com/test-kitchen/kitchen-dokken/commit/f13a4ba))

## 2.13.0 (2021-06-11)

- Add support for running the slow resource report in Chef Infra Client 17.2+ with a new `slow_resource_config` option in the provisioner
- Add the ability to set hostname aliases with a new `hostname_aliases` config in the driver [@npmeyer](https://github.com/npmeyer)
- Fix execution failures on Windows [@jakauppila](https://github.com/jakauppila)
- Fix failures when running on Podman [@tomhughes](https://github.com/tomhughes)

* Remove the Travis CI badge ([3b4430b](https://github.com/test-kitchen/kitchen-dokken/commit/3b4430b))
* Fix typos in the readme ([2e08cae](https://github.com/test-kitchen/kitchen-dokken/commit/2e08cae))
* Update chefstyle requirement from 1.7.1 to 1.7.2 ([#223](https://github.com/test-kitchen/kitchen-dokken/pull/223)) ([f4e2678](https://github.com/test-kitchen/kitchen-dokken/commit/f4e2678))
* Update chefstyle requirement from 1.7.2 to 1.7.4 ([#228](https://github.com/test-kitchen/kitchen-dokken/pull/228)) ([7657544](https://github.com/test-kitchen/kitchen-dokken/commit/7657544))
* Update chefstyle requirement from 1.7.4 to 1.7.5 ([#230](https://github.com/test-kitchen/kitchen-dokken/pull/230)) ([2cc797e](https://github.com/test-kitchen/kitchen-dokken/commit/2cc797e))
* Fixes for Windows Execution ([#232](https://github.com/test-kitchen/kitchen-dokken/pull/232)) ([3c9ccb0](https://github.com/test-kitchen/kitchen-dokken/commit/3c9ccb0))
* Add an hostname_aliases parameter ([#219](https://github.com/test-kitchen/kitchen-dokken/pull/219)) ([122b664](https://github.com/test-kitchen/kitchen-dokken/commit/122b664))
* Upgrade to GitHub-native Dependabot ([#233](https://github.com/test-kitchen/kitchen-dokken/pull/233)) ([6666549](https://github.com/test-kitchen/kitchen-dokken/commit/6666549))
* Update chefstyle requirement from 1.7.5 to 2.0.4 ([#237](https://github.com/test-kitchen/kitchen-dokken/pull/237)) ([d6a93df](https://github.com/test-kitchen/kitchen-dokken/commit/d6a93df))
* Add the slow_resource_report config option ([#238](https://github.com/test-kitchen/kitchen-dokken/pull/238)) ([936311f](https://github.com/test-kitchen/kitchen-dokken/commit/936311f))
* Pass credentials hash when creating an image ([#235](https://github.com/test-kitchen/kitchen-dokken/pull/235)) ([c901f52](https://github.com/test-kitchen/kitchen-dokken/commit/c901f52))

## 2.12.1 (2021-03-01)

- Further improvements for using `docker_registry` to use a Docker Registry other than DockerHub [@jaymzh](https://github.com/jaymzh)

* Fix `docker_registry` plus some cleanups ([#221](https://github.com/test-kitchen/kitchen-dokken/pull/221)) ([e22c503](https://github.com/test-kitchen/kitchen-dokken/commit/e22c503))

## 2.12.0 (2021-02-23)

- Add a new `docker_registry` config option for specifying customer docker registry URLs [@jaymzh](https://github.com/jaymzh)

* Add profile_ruby config to match chef-zero ([#212](https://github.com/test-kitchen/kitchen-dokken/pull/212)) ([1836e73](https://github.com/test-kitchen/kitchen-dokken/commit/1836e73))
* Require Ruby 2.5 + apply cookstyle linting ([#213](https://github.com/test-kitchen/kitchen-dokken/pull/213)) ([e968d5a](https://github.com/test-kitchen/kitchen-dokken/commit/e968d5a))
* Update README.md ([a6399a8](https://github.com/test-kitchen/kitchen-dokken/commit/a6399a8))
* Rename the kitchen file ([51fdda9](https://github.com/test-kitchen/kitchen-dokken/commit/51fdda9))
* Update chefstyle requirement from =1.5.9 to 1.6.1 ([#214](https://github.com/test-kitchen/kitchen-dokken/pull/214)) ([bbfc245](https://github.com/test-kitchen/kitchen-dokken/commit/bbfc245))
* Update chefstyle requirement from 1.6.1 to 1.6.2 ([#215](https://github.com/test-kitchen/kitchen-dokken/pull/215)) ([1d9eb24](https://github.com/test-kitchen/kitchen-dokken/commit/1d9eb24))
* Update chefstyle requirement from 1.6.2 to 1.7.1 ([#216](https://github.com/test-kitchen/kitchen-dokken/pull/216)) ([816a1ec](https://github.com/test-kitchen/kitchen-dokken/commit/816a1ec))
* Add 'docker_registry' option ([#218](https://github.com/test-kitchen/kitchen-dokken/pull/218)) ([cbc2851](https://github.com/test-kitchen/kitchen-dokken/commit/cbc2851))
* Add documentation for `docker_registry` ([#220](https://github.com/test-kitchen/kitchen-dokken/pull/220)) ([f8c76d2](https://github.com/test-kitchen/kitchen-dokken/commit/f8c76d2))

## 2.11.2 (2020-12-07)

- Resolve failures when using docker-api 2.x gem

* Fix typo in error message. ([#209](https://github.com/test-kitchen/kitchen-dokken/pull/209)) ([041c266](https://github.com/test-kitchen/kitchen-dokken/commit/041c266))
* Fix bad concatenation in error message ([#210](https://github.com/test-kitchen/kitchen-dokken/pull/210)) ([6e01409](https://github.com/test-kitchen/kitchen-dokken/commit/6e01409))
* Fix for Nil TypeError when Creating Containers ([#211](https://github.com/test-kitchen/kitchen-dokken/pull/211)) ([63d0250](https://github.com/test-kitchen/kitchen-dokken/commit/63d0250))

## 2.11.1 (2020-10-19)

- When checking if a port is open consider it closed if the network is down or otherwise unreachable

* Handle unreachable network errors ([#206](https://github.com/test-kitchen/kitchen-dokken/pull/206)) ([3aae147](https://github.com/test-kitchen/kitchen-dokken/commit/3aae147))

## 2.11.0 (2020-09-14)

- Allow docker-api gem version 2.0, which works with newer docker API releases and is Ruby 2.7 compatible

* Optimize our requires and use .match? not .match ([#202](https://github.com/test-kitchen/kitchen-dokken/pull/202)) ([4f1cfa9](https://github.com/test-kitchen/kitchen-dokken/commit/4f1cfa9))
* Allow docker-api 2.0 which removes the API version constraint ([#204](https://github.com/test-kitchen/kitchen-dokken/pull/204)) ([a3e6bdd](https://github.com/test-kitchen/kitchen-dokken/commit/a3e6bdd))
* Release kitchen-dokken 2.11 ([84fa44a](https://github.com/test-kitchen/kitchen-dokken/commit/84fa44a))

## 2.10.0 (2020-07-14)

- Added a new `memory_limit` config to set memory limits on the container. Thanks `@shanethehat`

* Fixes #167 Allow configurable container memory limit ([#192](https://github.com/test-kitchen/kitchen-dokken/pull/192)) ([e7756ed](https://github.com/test-kitchen/kitchen-dokken/commit/e7756ed))

## 2.9.1 (2020-07-14)

- Add docs for internal CA and MITM proxy Thanks `@Tensibai`
- Fix using `multiple_converge`. Thanks `@ramereth`

* Add doc for internal CA and MITM proxy ([#193](https://github.com/test-kitchen/kitchen-dokken/pull/193)) ([8200539](https://github.com/test-kitchen/kitchen-dokken/commit/8200539))
* Fix multiple_converge ([#195](https://github.com/test-kitchen/kitchen-dokken/pull/195)) ([00cd71d](https://github.com/test-kitchen/kitchen-dokken/commit/00cd71d))

## 2.9.0 (2020-05-06)

- Add a new provisioning configuration `clean_dokken_sandbox` to allow not cleaning up the Chef Infra and Test Kitchen files between converges to speed up repeatedly converging systems. This defaults to true which maintains the existing behavior. Thanks `@chrisUsick`

* Create option for leaving the kitchen sandbox between converges ([#191](https://github.com/test-kitchen/kitchen-dokken/pull/191)) ([0563d69](https://github.com/test-kitchen/kitchen-dokken/commit/0563d69))

## 2.8.2 (2020-03-10)

- Use `/opt/chef/bin/chef-client` not `/opt/chef/embedded/bin/chef-client` by default.

* Remove embedded from chef-client path ([#190](https://github.com/test-kitchen/kitchen-dokken/pull/190)) ([5537787](https://github.com/test-kitchen/kitchen-dokken/commit/5537787))

## 2.8.1 (2019-12-12)

- Correct container env arg (env -> Env) to match driver config

## 2.8.0 (2019-10-16)

- Set CI and TEST_KITCHEN environment variables to match other Test Kitchen drivers

* Update CHANGELOG.md ([470ec07](https://github.com/test-kitchen/kitchen-dokken/commit/470ec07))
* Update README.md ([#186](https://github.com/test-kitchen/kitchen-dokken/pull/186)) ([e5d3340](https://github.com/test-kitchen/kitchen-dokken/commit/e5d3340))

## 2.7.0 (2019-05-29)

- Add the ability to disable user namespace mode when running privileged containers with a new `userns_host` config option. See the readme for details.
- Added a new option `pull_chef_image` (true/false) to control force pulling the chef image on each run to check for newer images. This now defaults to true so that testing on latest and current always actually means latest and current.

* Update CHANGELOG.md ([20e18e0](https://github.com/test-kitchen/kitchen-dokken/commit/20e18e0))
* Fix test that is missing license acceptance value ([#179](https://github.com/test-kitchen/kitchen-dokken/pull/179)) ([cad71ab](https://github.com/test-kitchen/kitchen-dokken/commit/cad71ab))
* Add ability to disable user namespace mode when running privileged containers ([#172](https://github.com/test-kitchen/kitchen-dokken/pull/172)) ([4d3619b](https://github.com/test-kitchen/kitchen-dokken/commit/4d3619b))
* By default pull the chef docker image on every run ([#181](https://github.com/test-kitchen/kitchen-dokken/pull/181)) ([7e51cd8](https://github.com/test-kitchen/kitchen-dokken/commit/7e51cd8))

## 2.6.9 (2019-05-23)

- Support Chef Infra Client 15+ license acceptance. If the license has been accepted on your local workstation it will be passed through the Chef Infra installation. The license can also be set via the `chef_license` configuration property. See <https://docs.chef.io/chef_license_accept.html> for more details.
- Add a new config option `pull_platform_image` (true/false) which allows you to disable pulling the platform image on every dokken converge/test. This is particularly useful for local image testing.

* Update the changelog ([3fd1fd7](https://github.com/test-kitchen/kitchen-dokken/commit/3fd1fd7))
* Enable local image testing with a new pull_platform_image config ([#173](https://github.com/test-kitchen/kitchen-dokken/pull/173)) ([e9173c5](https://github.com/test-kitchen/kitchen-dokken/commit/e9173c5))
* Expand the readme ([fb595be](https://github.com/test-kitchen/kitchen-dokken/commit/fb595be))
* Copy chef_version into provisioner so license acceptance works correctly ([#178](https://github.com/test-kitchen/kitchen-dokken/pull/178)) ([e556d57](https://github.com/test-kitchen/kitchen-dokken/commit/e556d57))

## 2.6.8 (2019-03-19)

- Loosen the Test Kitchen dependency to allow this plugin to be used with the upcoming Test Kitchen 2.0 release
- Added a Rakefile to make it easier to ship build/install/release the gem
- Various readme improvements to clarify how to use the plugin
- Fix terminal size issue when using kitchen login
- Fail with a friendly warning if docker can't be found

* Add a Rakefile for gem releasing ([1981de0](https://github.com/test-kitchen/kitchen-dokken/commit/1981de0))
* Update README.md ([#145](https://github.com/test-kitchen/kitchen-dokken/pull/145)) ([c3ee365](https://github.com/test-kitchen/kitchen-dokken/commit/c3ee365))
* Adds the mention of Docker Hub to the README ([#146](https://github.com/test-kitchen/kitchen-dokken/pull/146)) ([597f4b3](https://github.com/test-kitchen/kitchen-dokken/commit/597f4b3))
* removing biden ([ef45d72](https://github.com/test-kitchen/kitchen-dokken/commit/ef45d72))
* adding biden ([6dac1be](https://github.com/test-kitchen/kitchen-dokken/commit/6dac1be))
* README Update: How to cache apt downloads ([#155](https://github.com/test-kitchen/kitchen-dokken/pull/155)) ([ec689e9](https://github.com/test-kitchen/kitchen-dokken/commit/ec689e9))
* Friendly error message when docker can't be reached ([#158](https://github.com/test-kitchen/kitchen-dokken/pull/158)) ([42be6ba](https://github.com/test-kitchen/kitchen-dokken/commit/42be6ba))
* Add gem version badge to the readme ([c4d3fd5](https://github.com/test-kitchen/kitchen-dokken/commit/c4d3fd5))
* Remove busted image from readme ([c5068c5](https://github.com/test-kitchen/kitchen-dokken/commit/c5068c5))
* Test on ruby 2.5.1 and avoid dev dep ([#159](https://github.com/test-kitchen/kitchen-dokken/pull/159)) ([19133db](https://github.com/test-kitchen/kitchen-dokken/commit/19133db))
* README.md: fix wrong URL ([#168](https://github.com/test-kitchen/kitchen-dokken/pull/168)) ([5e4ee8b](https://github.com/test-kitchen/kitchen-dokken/commit/5e4ee8b))
* Don't ship the changelog in the the gem artifact ([192fce5](https://github.com/test-kitchen/kitchen-dokken/commit/192fce5))
* fix the automatic tests ([#164](https://github.com/test-kitchen/kitchen-dokken/pull/164)) ([0b2062d](https://github.com/test-kitchen/kitchen-dokken/commit/0b2062d))
* Loosen the Test-Kitchen dep to allow 2.0 ([#174](https://github.com/test-kitchen/kitchen-dokken/pull/174)) ([0f32eec](https://github.com/test-kitchen/kitchen-dokken/commit/0f32eec))

## 2.6.7 (2018-03-05)

- Fix a potential race condition that may have led to the error 'Did not find config file: /opt/kitchen/client.rb'

* Single operation for directory creation and mode ([#144](https://github.com/test-kitchen/kitchen-dokken/pull/144)) ([e154ab6](https://github.com/test-kitchen/kitchen-dokken/commit/e154ab6))

## 2.6.6

- Improving the error message handling with intermediate builder
- README updates

* removing empty file ([a1c7b37](https://github.com/test-kitchen/kitchen-dokken/commit/a1c7b37))
* adding section on dokken-images to README.md ([e0fed1d](https://github.com/test-kitchen/kitchen-dokken/commit/e0fed1d))
* minor edits ([934628d](https://github.com/test-kitchen/kitchen-dokken/commit/934628d))
* yaml ([7bb3d4f](https://github.com/test-kitchen/kitchen-dokken/commit/7bb3d4f))
* Update the readme to show using dokken-images ([#127](https://github.com/test-kitchen/kitchen-dokken/pull/127)) ([17d3846](https://github.com/test-kitchen/kitchen-dokken/commit/17d3846))
* add a note about using `chef_image` to overwrite an image ([#135](https://github.com/test-kitchen/kitchen-dokken/pull/135)) ([3cb345e](https://github.com/test-kitchen/kitchen-dokken/commit/3cb345e))
* commiting 2.6.6 changes ([a9538cc](https://github.com/test-kitchen/kitchen-dokken/commit/a9538cc))

## 2.6.5

- Fixing cleanup_sandbox bug. Method from test-kitchen was causing the mount to break. Replaced it with one that globs.

* fixing sandbox cleanup bug ([2d01b66](https://github.com/test-kitchen/kitchen-dokken/commit/2d01b66))
* CHANGELOG and metadata ([4b53140](https://github.com/test-kitchen/kitchen-dokken/commit/4b53140))

## 2.6.4

- Fixing pull_image method to check for new id

* updating and using pull_image method ([c146106](https://github.com/test-kitchen/kitchen-dokken/commit/c146106))
* CHANGELOG and metadata ([a0dd015](https://github.com/test-kitchen/kitchen-dokken/commit/a0dd015))

## 2.6.3

- tmpfs support

* Add Tmpfs Support ([#123](https://github.com/test-kitchen/kitchen-dokken/pull/123)) ([3dd92db](https://github.com/test-kitchen/kitchen-dokken/commit/3dd92db))
* version and CHANGELOG ([98ec5b6](https://github.com/test-kitchen/kitchen-dokken/commit/98ec5b6))

## 2.6.2

- Removing NotFoundError from with_retries method

* Merge branch 'master' of github.com:someara/kitchen-dokken ([e0d3dce](https://github.com/test-kitchen/kitchen-dokken/commit/e0d3dce))
* Exclude NotFoundError from Errors that Trigger Retries ([#122](https://github.com/test-kitchen/kitchen-dokken/pull/122)) ([b6f3cd5](https://github.com/test-kitchen/kitchen-dokken/commit/b6f3cd5))
* bumping version and CHANGELOG ([c534d2c](https://github.com/test-kitchen/kitchen-dokken/commit/c534d2c))

## 2.6.1

- bugfix issue #118 - Ensuring sandbox cleanup on local docker hosts

* bumping version and CHANGELOG ([088ba4e](https://github.com/test-kitchen/kitchen-dokken/commit/088ba4e))

## 2.6.0

- Support for testing without provisioner converging
- entrypoint config

* using dokken/fedora-latest in .kitchen.yml ([967e69d](https://github.com/test-kitchen/kitchen-dokken/commit/967e69d))
* kicking travis ([d806641](https://github.com/test-kitchen/kitchen-dokken/commit/d806641))
* bumping version and CHANGELOG ([114fbb3](https://github.com/test-kitchen/kitchen-dokken/commit/114fbb3))

## 2.5.1

- re-adding boot2docker detection

* kick ([a5f4e88](https://github.com/test-kitchen/kitchen-dokken/commit/a5f4e88))
* updating CHANGELOG ([8c0900c](https://github.com/test-kitchen/kitchen-dokken/commit/8c0900c))
* fixing merge conflict in CHANGELOG ([c502d6b](https://github.com/test-kitchen/kitchen-dokken/commit/c502d6b))
* updating version number ([2ed012e](https://github.com/test-kitchen/kitchen-dokken/commit/2ed012e))

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

* adding example port configurations to .kitchen.yml ([c939711](https://github.com/test-kitchen/kitchen-dokken/commit/c939711))
* adding support for port mapping ([2d98b39](https://github.com/test-kitchen/kitchen-dokken/commit/2d98b39))
* adding tests for inter-container networking ([dbf926f](https://github.com/test-kitchen/kitchen-dokken/commit/dbf926f))
* using jerome's dind container ([dbd0bae](https://github.com/test-kitchen/kitchen-dokken/commit/dbd0bae))
* tweaking data container ip calculation bits ([8498961](https://github.com/test-kitchen/kitchen-dokken/commit/8498961))
* CHANGELOG and metadata bump ([90108b1](https://github.com/test-kitchen/kitchen-dokken/commit/90108b1))

## 2.4.3

- Using better paths for lock files

* using better paths for lockfiles ([18ab9b6](https://github.com/test-kitchen/kitchen-dokken/commit/18ab9b6))
* CHANGELOG and metadata bump ([0a2d11f](https://github.com/test-kitchen/kitchen-dokken/commit/0a2d11f))

- Using lockfile gem around chef-client container and dokken network creation

## 2.4.1

- Adding NotFoundError to with_retries and beefing up rescues

* using master branch in tests ([7ce4150](https://github.com/test-kitchen/kitchen-dokken/commit/7ce4150))
* running bundle exec tests in serial for now ([54ff780](https://github.com/test-kitchen/kitchen-dokken/commit/54ff780))
* try try again ([8f6240a](https://github.com/test-kitchen/kitchen-dokken/commit/8f6240a))
* CHANGELOG and metadata bump ([529b2b5](https://github.com/test-kitchen/kitchen-dokken/commit/529b2b5))

- Actually doing the things in 2.3.0

- Features meant for 2.2.0, but tested properly this time.
- Initial support for clusters / inter-suite name resolution
- Dokken now creates a user-defined network named "dokken" and connects containers to it. This allows us to take advantage of the built-in DNS server that in Docker 1.10 and later.
  ```yaml
   driver:
     hostname: example.com
  ```

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

- Uses chef/chef (instead of someara/chef)
- Bind mounts data instead of uploading through kitchen-cache container when talking to a local Docker host. (most use cases)
- Renders a Dockerfile and builds dokken/kitchen-cache when talking to a remote Docker host. (DOCKER_HOST =~ /^tcp:/)

## 1.1.0 (2017-01-04)

* savegame: kitchen create working ([50e45c6](https://github.com/test-kitchen/kitchen-dokken/commit/50e45c6))
* updating README ([58ef447](https://github.com/test-kitchen/kitchen-dokken/commit/58ef447))
* savegame: destroy working ([3b82dab](https://github.com/test-kitchen/kitchen-dokken/commit/3b82dab))
* savegame: leaving chef and kitchen_sandbox data containers static ([d3e4c3b](https://github.com/test-kitchen/kitchen-dokken/commit/d3e4c3b))
* savegame: getting network information to upload transport method ([b2dc043](https://github.com/test-kitchen/kitchen-dokken/commit/b2dc043))
* savegame: moving runner creation into transport ([13571c4](https://github.com/test-kitchen/kitchen-dokken/commit/13571c4))
* removing bitmover container ([dda0739](https://github.com/test-kitchen/kitchen-dokken/commit/dda0739))
* savegame: converge, reconverge and destroy working ([2585947](https://github.com/test-kitchen/kitchen-dokken/commit/2585947))
* savegame: chef-containers for everyone ([63d85ea](https://github.com/test-kitchen/kitchen-dokken/commit/63d85ea))
* fixing pull_if_missing ([dd6c177](https://github.com/test-kitchen/kitchen-dokken/commit/dd6c177))
* trying to load transport from plugin ([aef9b23](https://github.com/test-kitchen/kitchen-dokken/commit/aef9b23))
* fixing transport path ([d7627b0](https://github.com/test-kitchen/kitchen-dokken/commit/d7627b0))
* refactoring create bits ([aa8454f](https://github.com/test-kitchen/kitchen-dokken/commit/aa8454f))
* enabling ssl for excon ([3018430](https://github.com/test-kitchen/kitchen-dokken/commit/3018430))
* Merge branch 'master' of github.com:someara/kitchen-dokken ([76f04fe](https://github.com/test-kitchen/kitchen-dokken/commit/76f04fe))
* readme ([c325176](https://github.com/test-kitchen/kitchen-dokken/commit/c325176))
* gutting plugin. adding provisioner ([840a4b5](https://github.com/test-kitchen/kitchen-dokken/commit/840a4b5))
* making not-ugly ([6fd0c0b](https://github.com/test-kitchen/kitchen-dokken/commit/6fd0c0b))
* savegame: converge and verify both working ([e2cdc8d](https://github.com/test-kitchen/kitchen-dokken/commit/e2cdc8d))
* removing image commit ([1d604f2](https://github.com/test-kitchen/kitchen-dokken/commit/1d604f2))
* savegame: removing color debug string ([59e335d](https://github.com/test-kitchen/kitchen-dokken/commit/59e335d))
* savegame: sending execute output to logger ([db54f15](https://github.com/test-kitchen/kitchen-dokken/commit/db54f15))
* removing doc formatting ([16d5525](https://github.com/test-kitchen/kitchen-dokken/commit/16d5525))
* savegame: attempting insecure ssh key ([e9f2e6e](https://github.com/test-kitchen/kitchen-dokken/commit/e9f2e6e))
* savegame: insecure key works ([ca89a90](https://github.com/test-kitchen/kitchen-dokken/commit/ca89a90))
* savegame: rsync command tweaking ([b6852f6](https://github.com/test-kitchen/kitchen-dokken/commit/b6852f6))
* switching execute to native, handing failure ([9e38d38](https://github.com/test-kitchen/kitchen-dokken/commit/9e38d38))
* savegame: nothing to see here ([c22811c](https://github.com/test-kitchen/kitchen-dokken/commit/c22811c))
* savegame: reverting to system() for transport execute ([5980a63](https://github.com/test-kitchen/kitchen-dokken/commit/5980a63))
* savegame: login command working ([4e4773c](https://github.com/test-kitchen/kitchen-dokken/commit/4e4773c))
* savegame: saving work before moving some methods around ([6e4026b](https://github.com/test-kitchen/kitchen-dokken/commit/6e4026b))
* breaking driver create method up into smaller chunks ([21d963f](https://github.com/test-kitchen/kitchen-dokken/commit/21d963f))
* pid_one_command working ([bc7e54b](https://github.com/test-kitchen/kitchen-dokken/commit/bc7e54b))
* renaming runner ([50a1596](https://github.com/test-kitchen/kitchen-dokken/commit/50a1596))
* removing some cruft ([a128de2](https://github.com/test-kitchen/kitchen-dokken/commit/a128de2))
* creating work_image ([cc6e485](https://github.com/test-kitchen/kitchen-dokken/commit/cc6e485))
* cops ([acadec2](https://github.com/test-kitchen/kitchen-dokken/commit/acadec2))
* adding work_image ([edf2eaf](https://github.com/test-kitchen/kitchen-dokken/commit/edf2eaf))
* suppor for privileged containers ([ac311bf](https://github.com/test-kitchen/kitchen-dokken/commit/ac311bf))
* switching from sleep900 to trapping SIGTERM ([9c73174](https://github.com/test-kitchen/kitchen-dokken/commit/9c73174))
* switching to /opt from /tmp to avoid fedora tmpfs on tmp ([40766e9](https://github.com/test-kitchen/kitchen-dokken/commit/40766e9))
* removing debug ([51ac5ee](https://github.com/test-kitchen/kitchen-dokken/commit/51ac5ee))
* first pass at connection info and timeouts ([ac8e0d8](https://github.com/test-kitchen/kitchen-dokken/commit/ac8e0d8))
* fixing the transport up a bit ([e4c9862](https://github.com/test-kitchen/kitchen-dokken/commit/e4c9862))
* cleanup ([6ec4dbe](https://github.com/test-kitchen/kitchen-dokken/commit/6ec4dbe))
* sharing chef container among instances ([cd3f848](https://github.com/test-kitchen/kitchen-dokken/commit/cd3f848))
* renaming 'kitchen_cache' to 'data' ([a7e3e7a](https://github.com/test-kitchen/kitchen-dokken/commit/a7e3e7a))
* rescuing create_container conflicts ([5010d2d](https://github.com/test-kitchen/kitchen-dokken/commit/5010d2d))
* reverting to data container per instance ([ad8b27c](https://github.com/test-kitchen/kitchen-dokken/commit/ad8b27c))
* pulling instead of building data_image ([1dd9843](https://github.com/test-kitchen/kitchen-dokken/commit/1dd9843))
* making login_command a public method ([3376e9a](https://github.com/test-kitchen/kitchen-dokken/commit/3376e9a))
* updating deps ([1245aad](https://github.com/test-kitchen/kitchen-dokken/commit/1245aad))
* updating gemspec ([bb68a74](https://github.com/test-kitchen/kitchen-dokken/commit/bb68a74))
* updating version ([ebfcd89](https://github.com/test-kitchen/kitchen-dokken/commit/ebfcd89))
* cops ([b2d33f7](https://github.com/test-kitchen/kitchen-dokken/commit/b2d33f7))
* moving image_prefix, chef_version, and data_image into default_config ([32b400d](https://github.com/test-kitchen/kitchen-dokken/commit/32b400d))
* bumping to 0.0.2 ([495e1f6](https://github.com/test-kitchen/kitchen-dokken/commit/495e1f6))
* defaulting to unix socket in the absense of ENV['DOCKER_HOST'] ([e443814](https://github.com/test-kitchen/kitchen-dokken/commit/e443814))
* bumping to 0.0.3 ([b8e301d](https://github.com/test-kitchen/kitchen-dokken/commit/b8e301d))
* adding logic for unix:// docker_hosts_url ([35046c3](https://github.com/test-kitchen/kitchen-dokken/commit/35046c3))
* bumping to 0.0.4 ([de5c690](https://github.com/test-kitchen/kitchen-dokken/commit/de5c690))
* adding test-kitchen harness ([cc4f573](https://github.com/test-kitchen/kitchen-dokken/commit/cc4f573))
* tweaking travis ([f7e5672](https://github.com/test-kitchen/kitchen-dokken/commit/f7e5672))
* tweaking Gemfile and travis ([4334422](https://github.com/test-kitchen/kitchen-dokken/commit/4334422))
* updating spec.files ([d2114a0](https://github.com/test-kitchen/kitchen-dokken/commit/d2114a0))
* adding serverspec tests ([f637339](https://github.com/test-kitchen/kitchen-dokken/commit/f637339))
* tweaking .travis.yml, adding multiple Chef versions ([6c090d3](https://github.com/test-kitchen/kitchen-dokken/commit/6c090d3))
* tweaking .travis.yml ([256bfb6](https://github.com/test-kitchen/kitchen-dokken/commit/256bfb6))
* testing full kitchen test ([ac6e63d](https://github.com/test-kitchen/kitchen-dokken/commit/ac6e63d))
* requiring serverspec ([212ca7a](https://github.com/test-kitchen/kitchen-dokken/commit/212ca7a))
* trying sudo false ([20bc9a8](https://github.com/test-kitchen/kitchen-dokken/commit/20bc9a8))
* running full build matrix ([81afc84](https://github.com/test-kitchen/kitchen-dokken/commit/81afc84))
* initial README ([32f1067](https://github.com/test-kitchen/kitchen-dokken/commit/32f1067))
* [ci skip] - working on README ([d2aff02](https://github.com/test-kitchen/kitchen-dokken/commit/d2aff02))
* README updates ([b98b44f](https://github.com/test-kitchen/kitchen-dokken/commit/b98b44f))
* [ci skip] - More README work ([d6772a1](https://github.com/test-kitchen/kitchen-dokken/commit/d6772a1))
* [ci skip] - Minor README tweaks ([1ad9e16](https://github.com/test-kitchen/kitchen-dokken/commit/1ad9e16))
* adding comment to workimage dockerfile ([4804718](https://github.com/test-kitchen/kitchen-dokken/commit/4804718))
* Fixing up README ([2790f52](https://github.com/test-kitchen/kitchen-dokken/commit/2790f52))
* switching to -F doc and removing stream print ([e9ce941](https://github.com/test-kitchen/kitchen-dokken/commit/e9ce941))
* bumping version ([146cdc0](https://github.com/test-kitchen/kitchen-dokken/commit/146cdc0))
* switching to print in transport execute ([7549f09](https://github.com/test-kitchen/kitchen-dokken/commit/7549f09))
* specifying warn in provisioner ([6d709fc](https://github.com/test-kitchen/kitchen-dokken/commit/6d709fc))
* updating kitchen converge output ([649fe02](https://github.com/test-kitchen/kitchen-dokken/commit/649fe02))
* [ci skip] - README tweak ([14fc822](https://github.com/test-kitchen/kitchen-dokken/commit/14fc822))
* [ci skip] - tweaking README.md ([375da8a](https://github.com/test-kitchen/kitchen-dokken/commit/375da8a))
* adding retries to container operations in driver ([5e03c45](https://github.com/test-kitchen/kitchen-dokken/commit/5e03c45))
* removing debug print ([aa8e57a](https://github.com/test-kitchen/kitchen-dokken/commit/aa8e57a))
* misc fixes ([ecfe7cb](https://github.com/test-kitchen/kitchen-dokken/commit/ecfe7cb))
* adding retries and timeouts to driver ([7022262](https://github.com/test-kitchen/kitchen-dokken/commit/7022262))
* adding retries to transport ([7fda993](https://github.com/test-kitchen/kitchen-dokken/commit/7fda993))
* adding more retries ([bfb508a](https://github.com/test-kitchen/kitchen-dokken/commit/bfb508a))
* more retries and polling ([a4ff93e](https://github.com/test-kitchen/kitchen-dokken/commit/a4ff93e))
* using forcerm ([500df41](https://github.com/test-kitchen/kitchen-dokken/commit/500df41))
* fixing retry logic ([81dad1e](https://github.com/test-kitchen/kitchen-dokken/commit/81dad1e))
* fixing up delete logic ([b09d912](https://github.com/test-kitchen/kitchen-dokken/commit/b09d912))
* refactoring methods a bit ([b39d528](https://github.com/test-kitchen/kitchen-dokken/commit/b39d528))
* tagging work_image with same API call as build ([ea02b2b](https://github.com/test-kitchen/kitchen-dokken/commit/ea02b2b))
* replacing someara/chef with chef/chef ([657da5c](https://github.com/test-kitchen/kitchen-dokken/commit/657da5c))
* disabling post-execute image commit in transport ([ce28d99](https://github.com/test-kitchen/kitchen-dokken/commit/ce28d99))
* Use kitchen logger to keep log files and color output ([#5](https://github.com/test-kitchen/kitchen-dokken/pull/5)) ([ab459ea](https://github.com/test-kitchen/kitchen-dokken/commit/ab459ea))
* Revert "Use kitchen logger to keep log files and color output" ([fd02431](https://github.com/test-kitchen/kitchen-dokken/commit/fd02431))
* allow the log level to be specified in the provisioner configuration ([#7](https://github.com/test-kitchen/kitchen-dokken/pull/7)) ([b7e9ab2](https://github.com/test-kitchen/kitchen-dokken/commit/b7e9ab2))
* Revert "allow the log level to be specified in the provisioner configuration" ([cfcfc91](https://github.com/test-kitchen/kitchen-dokken/commit/cfcfc91))
* updating docker-api ([5ffd7da](https://github.com/test-kitchen/kitchen-dokken/commit/5ffd7da))
* adding docker --version to after script ([31d0027](https://github.com/test-kitchen/kitchen-dokken/commit/31d0027))
* depending on docker-api ~&gt; 1.26.1 ([14044e2](https://github.com/test-kitchen/kitchen-dokken/commit/14044e2))
* bug fix in image creation ([97d8e99](https://github.com/test-kitchen/kitchen-dokken/commit/97d8e99))
* Re-indent example .kitchen.yml ([#10](https://github.com/test-kitchen/kitchen-dokken/pull/10)) ([239154d](https://github.com/test-kitchen/kitchen-dokken/commit/239154d))
* Add in some exception handling to figure out what went wrong with image building ([#12](https://github.com/test-kitchen/kitchen-dokken/pull/12)) ([a3e4060](https://github.com/test-kitchen/kitchen-dokken/commit/a3e4060))
* read rsync ip from data container ([#13](https://github.com/test-kitchen/kitchen-dokken/pull/13)) ([0f1c768](https://github.com/test-kitchen/kitchen-dokken/commit/0f1c768))
* Prevent collisions between docker-api and kitchen-docker ([#15](https://github.com/test-kitchen/kitchen-dokken/pull/15)) ([8130ea6](https://github.com/test-kitchen/kitchen-dokken/commit/8130ea6))
* updating docker-api version dep ([25509f9](https://github.com/test-kitchen/kitchen-dokken/commit/25509f9))
* Allow override of host ip ([#20](https://github.com/test-kitchen/kitchen-dokken/pull/20)) ([0bdab0e](https://github.com/test-kitchen/kitchen-dokken/commit/0bdab0e))
* Add common docker run args ([#21](https://github.com/test-kitchen/kitchen-dokken/pull/21)) ([e539c40](https://github.com/test-kitchen/kitchen-dokken/commit/e539c40))
* Two commits - #20 - Allow override of host ip - #21 - Add common docker run args ([94acabf](https://github.com/test-kitchen/kitchen-dokken/commit/94acabf))
* adding prefix to instance_name ([d04d2a5](https://github.com/test-kitchen/kitchen-dokken/commit/d04d2a5))
* 26 multiple suite destroy ([#27](https://github.com/test-kitchen/kitchen-dokken/pull/27)) ([5cee99e](https://github.com/test-kitchen/kitchen-dokken/commit/5cee99e))
* 14 add port forwards ([#23](https://github.com/test-kitchen/kitchen-dokken/pull/23)) ([5faae08](https://github.com/test-kitchen/kitchen-dokken/commit/5faae08))
* adding "privileged: true" to centos systemd example in README ([878add5](https://github.com/test-kitchen/kitchen-dokken/commit/878add5))
* using Dir.mktmpdir to build images ([170888b](https://github.com/test-kitchen/kitchen-dokken/commit/170888b))
* allowing user to specify chef_image ([4350872](https://github.com/test-kitchen/kitchen-dokken/commit/4350872))
* bumping to version 1.0.0 ([f27396e](https://github.com/test-kitchen/kitchen-dokken/commit/f27396e))
* using someara/chef. bumping version ([7052641](https://github.com/test-kitchen/kitchen-dokken/commit/7052641))
* Set the chef log level to be the same as for the kitchen run. ([#31](https://github.com/test-kitchen/kitchen-dokken/pull/31)) ([e2d82a8](https://github.com/test-kitchen/kitchen-dokken/commit/e2d82a8))
* Revert "Set the chef log level to be the same as for the kitchen run." ([#35](https://github.com/test-kitchen/kitchen-dokken/pull/35)) ([5383a09](https://github.com/test-kitchen/kitchen-dokken/commit/5383a09))
* adding profile_ruby support ([3a15ebc](https://github.com/test-kitchen/kitchen-dokken/commit/3a15ebc))
* Revert "adding profile_ruby support" ([940a3c2](https://github.com/test-kitchen/kitchen-dokken/commit/940a3c2))
* bumping to 1.0.3 ([1a00a29](https://github.com/test-kitchen/kitchen-dokken/commit/1a00a29))
* changing prefix generation technique ([e850a19](https://github.com/test-kitchen/kitchen-dokken/commit/e850a19))
* adding joe biden ([ff08343](https://github.com/test-kitchen/kitchen-dokken/commit/ff08343))
* updating test harness ([c164392](https://github.com/test-kitchen/kitchen-dokken/commit/c164392))
* updating travis config ([374c000](https://github.com/test-kitchen/kitchen-dokken/commit/374c000))
* allowing user to set container DNS settings ([33f1500](https://github.com/test-kitchen/kitchen-dokken/commit/33f1500))
* restoring gemspec ([1dc11f7](https://github.com/test-kitchen/kitchen-dokken/commit/1dc11f7))
* updating dependency versions ([917b82a](https://github.com/test-kitchen/kitchen-dokken/commit/917b82a))
* Use data container's IP if unix socket and SSH port is mapped to 0.0.0.0 ([#42](https://github.com/test-kitchen/kitchen-dokken/pull/42)) ([df27e4f](https://github.com/test-kitchen/kitchen-dokken/commit/df27e4f))
* adding intermediate_instructions to install upstart to amazonlinux suite ([5bfc96b](https://github.com/test-kitchen/kitchen-dokken/commit/5bfc96b))
* Use localhost if on Docker for Mac ([#46](https://github.com/test-kitchen/kitchen-dokken/pull/46)) ([c285ee2](https://github.com/test-kitchen/kitchen-dokken/commit/c285ee2))
* bumping metadata ([989c04b](https://github.com/test-kitchen/kitchen-dokken/commit/989c04b))
* Change defualt image to chef/chef ([#47](https://github.com/test-kitchen/kitchen-dokken/pull/47)) ([45f28dc](https://github.com/test-kitchen/kitchen-dokken/commit/45f28dc))
* depending on docker-api ~&gt; 1.33 ([2e3bfb0](https://github.com/test-kitchen/kitchen-dokken/commit/2e3bfb0))
* typo ([#51](https://github.com/test-kitchen/kitchen-dokken/pull/51)) ([1bc8660](https://github.com/test-kitchen/kitchen-dokken/commit/1bc8660))
* Add compatibility with Windows ([#52](https://github.com/test-kitchen/kitchen-dokken/pull/52)) ([8d59d37](https://github.com/test-kitchen/kitchen-dokken/commit/8d59d37))
* Adding Windows support. Bumping to 1.1.0 ([1867f6e](https://github.com/test-kitchen/kitchen-dokken/commit/1867f6e))
* adding KITCHEN_LOCAL_YAML to README ([fa0eb44](https://github.com/test-kitchen/kitchen-dokken/commit/fa0eb44))
* updating README for inspec ([ee47fd8](https://github.com/test-kitchen/kitchen-dokken/commit/ee47fd8))
* Pass along ENV variables in the provisioner ([#53](https://github.com/test-kitchen/kitchen-dokken/pull/53)) ([1b46acd](https://github.com/test-kitchen/kitchen-dokken/commit/1b46acd))
* Revert "Pass along ENV variables in the provisioner" ([8e0392d](https://github.com/test-kitchen/kitchen-dokken/commit/8e0392d))

## 1.0.0

- First stable release.
- Relied on someara/chef and someara/kitchen-cache from the Docker hub.
