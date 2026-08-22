#
# Deliberately small and deliberately idempotent.
#
# These suites exist to exercise the *driver* -- networking, volumes, init,
# the sandbox -- not to exercise Chef. The recipe therefore has to converge
# cleanly a second time (the `idempotency` suite runs it twice with
# enforce_idempotency) and has to work on every platform in kitchen.yml, so it
# avoids packages and anything else that differs across distros.
#

directory "/opt/dokken-test" do
  owner "root"
  mode "0755"
end

file "/opt/dokken-test/converged" do
  content "ok\n"
  mode "0644"
end

user "dokken" do
  home "/home/dokken"
  manage_home true
  shell "/bin/sh"
end
