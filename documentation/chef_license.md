# Chef License Configuration for kitchen-dokken

## Overview

Chef Infra requires license acceptance to operate. This document outlines how this is handled in different environments and configurations for the kitchen-dokken project.

## License Acceptance Options

Chef provides several methods for accepting the license:

- `accept`: Accept the license and save the acceptance to the node.
- `accept-no-persist`: Accept the license but do not save the acceptance.
- `accept-silent`: Accept the license silently and save the acceptance.

## Configuration Locations

### CI/CD Environment

In CI/CD environments, we configure the CHEF_LICENSE environment variable to ensure proper operation:

```yaml
# In .github/workflows/lint.yml
env:
  CHEF_LICENSE: "accept"
```

### Local Development

For local development, you can set the CHEF_LICENSE environment variable:

```bash
# Fish shell
set -x CHEF_LICENSE accept

# Bash/Zsh
export CHEF_LICENSE=accept
```

Or you can add it to your shell profile for persistence.

### Test Kitchen Configuration

The Test Kitchen driver configuration in `kitchen.yml` includes CHEF_LICENSE configuration:

```yaml
driver:
  name: dokken
  chef_version: latest
  privileged: true
  volumes: [ '/var/lib/docker' ]
  env: [CHEF_LICENSE=accept]
```

## Troubleshooting

If you encounter license-related errors:

1. Ensure CHEF_LICENSE is properly set in your environment
2. Check that the license acceptance is being passed to all components (driver, provisioner, verifier)
3. For CI failures, verify that the workflow file includes the proper environment variable configuration

## References

- [Chef License Documentation](https://docs.chef.io/chef_license_accept/)
- [Test Kitchen Environment Variables](https://kitchen.ci/docs/provisioners/chef/#environment-variables/)
