# nodes related steps

# select a random node from a cluster.
Given /^I select a random node's host$/ do
  @host = env.node_hosts.sample
end

# @host from World will be used.
Given /^I run commands on the host:$/ do |table|
  ensure_admin_tagged

  raise "You must set a host prior to running this step" unless host

  @result = host.exec(*table.raw.flatten)
end
