# Contributing to kitchen-dokken

Thanks for helping out. This document covers how to get set up, how the two
test suites work, and what CI will run against your pull request.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

- [Getting set up](#getting-set-up)
- [Unit tests](#unit-tests)
- [Integration tests](#integration-tests)
- [Adding an integration suite](#adding-an-integration-suite)
- [Linting](#linting)
- [Documentation](#documentation)
- [What CI runs](#what-ci-runs)
- [Project layout](#project-layout)
- [Releasing](#releasing)

## Getting set up

You need Ruby 3.1 or later. A Docker daemon is only required for the
integration suites — the unit suite runs anywhere.

```shell
git clone https://github.com/test-kitchen/kitchen-dokken
cd kitchen-dokken
bundle install
```

The everyday command is:

```shell
bundle exec rake        # cookstyle + unit tests
```

## Unit tests

```shell
bundle exec rake unit                 # minitest, via spec/
```

The suite is **hermetic**, and new tests are expected to keep it that way. It
never contacts a Docker daemon, never reads your home directory, writes only
into a temporary directory, and never sleeps.

Two of those are enforced for you in `spec/spec_helper.rb`: every example gets
`Dir.home` pointed at an empty scratch directory, so nothing can read your real
`~/.docker/config.json` or `~/.ssh`. That guard exists because a test once
passed locally and failed on CI purely because the runner had Docker Hub
credentials on disk.

`CI` is removed from the environment for the same reason. The driver forwards
it into every container it creates, so an ambient `CI=true` makes any spec
that touches a container's `Env` assert against a different payload on a
runner than on a laptop — which is exactly how the create-payload snapshots
first broke. When you need to test environment-dependent behaviour, **force
the state with a stub** rather than inheriting it; see "forwards the CI
environment variable when kitchen runs in CI" in the driver spec.
`spec/suite_hermeticity_spec.rb` proves both guards are live.

When you need a Docker object, prefer the doubles in `spec/support` over
stubbing the `docker-api` gem globally, so a failing expectation points at
kitchen-dokken rather than at a fake.

### The layers, and what each one is for

Most specs test one method against per-call stubs, which is the right tool for
"does this method do the right thing". Four other layers exist because that
style is structurally blind to certain bugs:

| Layer | File | Catches |
| ----- | ---- | ------- |
| Seam contract | `spec/kitchen/docker_api_contract_spec.rb` | a `docker-api` upgrade renaming a method, changing its arity, or dropping an error class we rescue — and doubles that have drifted from the real classes |
| Lifecycle | `spec/kitchen/driver/lifecycle_spec.rb` | bugs that need daemon *state* to show up: create-twice, destroy-after-partial-create, stop-before-delete ordering |
| Handoff | `spec/kitchen/plugin_handoff_spec.rb` | the driver and transport disagreeing about kitchen state, which no single-plugin spec can see |
| Properties | `spec/kitchen/port_parsing_properties_spec.rb` | parser input nobody thought to write an example for |

Two supporting pieces are worth knowing about before you write a spec:

**`spec/support/fake_daemon.rb`** is an in-memory Docker daemon that holds
state and enforces the real one's invariants — `get` on an unknown name
raises `NotFoundError`, a duplicate `create` raises `ConflictError`, a
container is created stopped. Reach for it (`fake_daemon`) whenever a spec
exercises a *sequence* of operations; per-call stubs cannot express "and then
the container was gone". It replaces singleton methods on the `docker-api`
classes and `spec_helper.rb` uninstalls it after every example.

**Payload snapshots** in `spec/fixtures/payloads/` capture the whole container
create request for six representative configs. They sit alongside explicit
assertions rather than replacing them: the explicit ones say what must be
true, the snapshot notices everything else that moved. Regenerate with
`UPDATE_SNAPSHOTS=1 bundle exec rake unit` and **read the diff** — it names
the keys that changed, not the lines. A rubber-stamped snapshot update is
worse than no snapshot.

Mocha is configured to refuse a stub for a method that does not exist
(`stubbing_non_existent_method = :prevent`), so a typo like
`Docker::Image.stubs(:exist)` fails at stub time instead of quietly passing.
`spec/mocha_configuration_spec.rb` deliberately breaks that rule to prove the
setting is live — mocha treats an unrecognised value as "allow", so a
plausible-looking `:prohibit` would enforce nothing.

The property tests use a fixed seed so failures reproduce. Set `PORT_SEED` to
explore a different slice of the input space; the failure message tells you
which seed to reuse.

## Integration tests

`kitchen.yml` drives kitchen-dokken against a real daemon. Its suites are
organised by **driver feature** rather than by distro, because dokken's bugs
live in networking and volume plumbing rather than in distro differences:

| Suite | Exercises |
| --- | --- |
| `default` | converge, sandbox, mounted client, `pid_one_command` |
| `idempotency` | converging twice with nothing left to change |
| `bridge`, `host` | the network modes that skip endpoint configuration |
| `dns` | `dns` and `dns_search` |
| `ipv6` | the IPv6 `dokken` network |
| `tmpfs` | `tmpfs` mounts |
| `volumes` | anonymous volumes and read-only binds |
| `resources` | `memory_limit` |
| `hello` + `helloagain` | `entrypoint`, published ports, hostname aliases, `env` |
| `arch` | `platform` pinning to a non-host architecture |

```shell
bundle exec kitchen list
bundle exec kitchen test default-almalinux-9
bundle exec kitchen test                      # everything; takes a while
```

Some suites have prerequisites your daemon may not meet:

| Suite | Needs |
| --- | --- |
| `ipv6` | `{"experimental": true, "ip6tables": true}` in `/etc/docker/daemon.json` |
| `arch` | QEMU registered for the target architecture |
| `helloagain` | its peer up first: `kitchen create hello-alpine` |

### Why Cinc

These suites run against **Cinc**, so neither the converge nor the verify needs
a licence key. That is what lets them run on pull requests from forks, where
repository secrets are unavailable.

`inspec-core` is pinned below 6 for the same reason: from 6.6.0 the gem ships
under a Chef EULA and refuses to run without an entitlement. That pin is the
Apache-2.0 line Cinc Auditor is itself built from — there is no `cinc-auditor`
gem to depend on instead, because Cinc Auditor ships as omnibus packages and
`kitchen-inspec` loads InSpec in-process as a library.

To exercise the Chef Infra path instead, use the parallel config. You will need
a licence:

```shell
CHEF_LICENSE_KEY=<key> KITCHEN_YAML=kitchen.chef.yml bundle exec kitchen test
```

The driver's chef-vs-cinc branching is covered by the unit suite, so CI does
not run this config.

## Adding an integration suite

1. Add the suite to `kitchen.yml` with the driver settings you want to
   exercise. Use `excludes: [alpine]` if it needs a real init, or
   `includes: [alpine]` if it does not converge anything.
2. Add an InSpec profile under `test/integration/<suite>/inspec/`. Assert
   **observable behaviour**, not Docker's own implementation details — the
   `dns` profile is a cautionary tale, since it originally asserted literal
   `nameserver` lines that Docker's embedded resolver later stopped writing.
3. Add the suite name to the `features` matrix in
   `.github/workflows/integration.yml`. If it needs daemon setup, give it its
   own job instead, the way `ipv6` does.
4. Check it resolves: `bundle exec kitchen list`.

Reuse `test/integration/default` when the assertion really is just "this still
converges under that setting" — `bridge` and `host` both do.

## Linting

```shell
bundle exec rake style        # cookstyle, which also lints the test cookbooks
```

CI additionally runs `yamllint` over every YAML file and `markdownlint` over
every Markdown file except the changelog. Both use the configuration in the
repository root, so:

```shell
yamllint -c .yamllint.yml .
markdownlint --config .markdownlint.yaml '**/*.md'
```

## Documentation

Every method carries YARD documentation, public and private:

```shell
bundle exec rake doc          # generate into doc/
bundle exec rake doc_stats    # report undocumented objects
```

This is **not gated in CI**. Please document new methods anyway — the
`@return` tag in particular, since it is the one that says what a method is
actually for.

User-facing behaviour belongs in `README.md`. Contributor-facing process
belongs here.

## What CI runs

Two workflows, neither of which needs a secret:

| Workflow | Jobs |
| --- | --- |
| `lint.yml` | cookstyle, yamllint, markdownlint, and the unit suite on Ruby 3.1 – 4.0 |
| `integration.yml` | the suites above, on `almalinux-9` and `ubuntu-2404` |

`integration.yml` also holds two jobs that cannot be reproduced by running a
suite locally:

- **`arch`** registers QEMU first, so a non-host architecture can actually
  boot before `platform` pinning is tested.
- **`nested`** runs kitchen-dokken *inside* a container, which makes
  `running_inside_docker?` true. That is the only way to reach the data
  container and its ssh upload path without a genuinely remote daemon, and it
  covers both transfer implementations — rsync, and the `Net::SCP` fallback
  used when rsync is absent.

Every integration job is a full `kitchen test`, so InSpec really does assert
behaviour rather than the job merely proving that a converge exited zero. They
all run with `fail-fast: false`, so one broken suite will not hide the rest.

## Project layout

```text
lib/kitchen/driver/dokken.rb        containers, images, networks, registry auth
lib/kitchen/provisioner/dokken.rb   the sandbox and the chef-client invocation
lib/kitchen/transport/dokken.rb     docker exec, and file upload to the data container
lib/kitchen/helpers.rb              shared helpers, plus patches to Kitchen's base classes
spec/                               unit tests; spec/support holds the shared doubles
spec/support/fake_daemon.rb         an in-memory Docker daemon for lifecycle specs
spec/fixtures/payloads/             container create-request snapshots
test/cookbooks/                     the cookbook the integration suites converge
test/integration/                   one InSpec profile per suite
```

The driver, provisioner and transport all mix in `Dokken::Helpers` at the top
level, which puts those methods on `Object`. It is a wart, and worth knowing
about before you go looking for where a helper is defined.

## Releasing

Releases are automated by
[release-please](https://github.com/googleapis/release-please). Merging to
`main` opens or updates a release pull request; merging that tags the version
and publishes the gem. Write commit messages in
[Conventional Commits](https://www.conventionalcommits.org/) form so the
changelog comes out right.
