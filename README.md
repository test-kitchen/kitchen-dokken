Falling into the Docker rabbit hole
===================================

# Community Docker cookbook
1.0 branch, on Github at
- https://github.com/someara/chef-docker/tree/1.0

# kitchen2docker
- This cookbook is used to spin up a dockerhost on Digital Ocean.
- Berkshelf points to the 1.0 branch of the Docker cookbook
- After the machine is done converging, run . bin/kitchen2docker to
  initialize your shell. docker info should report overlayfs, etc.
- It contains two Dockerfiles used for building `chef` and
  `kitchen-cache` volume containers use by kitchen-dokken.
- My authorized_keys are hard coded into the kitchen-cache. You'll
  need to change that.
- Run the build.sh scripts in dockerfiles/chef and dockerfiles/kitchen-cache
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

# Known issues
- Cannot go from zero to "kitchen test -c" right off the bat.
- Must do a "kitchen create" first. I do now know why yet.
- Can't load transport from plugin. run dokken branch of test-kitchen.
  Why? No idea.
- hard coded authorized_keys
- hard coded someara/whatever all over the place         
- can't choose chef version yet
- can't choose platform versions yet
- supplement platform with start_image?                  
- kitchen converge error handling
- kitchen verify error handling                       
- further converges commit a new image, even when nothing changes.

# Pasties
b kitchen destroy -c
docker ps -aq | xargs docker kill
docker ps -aq | xargs docker rm
docker images -q | xargs docker rmi
