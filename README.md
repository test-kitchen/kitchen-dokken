Falling into the Docker rabbit hole
===================================

# Community Docker cookbook
1.0 branch, on Github at
- https://github.com/someara/chef-docker/tree/1.0

# kitchen2docker
- This cookbook is used to spin up a dockerhost on Digital Ocean.
- Berkshelf points to the 1.0 branch of the Docker cookbook
- It contains two Dockerfiles used for building `chef` and
  `kitchen-cache` volume containers use by kitchen-dokken.
- Run the build.sh scripts in dockerfiles. 
- Modifications required. s/someara/your_docker_repo_here/

# httpd
- Test cookbook for developing all this.
- Dokken branch at https://github.com/chef-cookbooks/httpd/tree/dokken
- export KITCHEN_YAML=.kitchen.dokken.yml
- Uses the 'dokken' branch of someara/test-kitchen for transport
- Uses the someara/kitchen-dokken plugin for driver
- bundle install
- bundle install kitchen list

# test-kitchen branch
The interesting stuff is split between this and kitchen-dokken.

- https://github.com/someara/test-kitchen/tree/dokken

# kitchen-dokken plugin
- https://github.com/someara/kitchen-dokken
