require 'openshift/route'
require 'openshift/service'

# e.g I expose the "myapp" service
When /^I expose(?: the)?(?: "(.+?)")? service$/ do |service_name|
  r = route(service_name, service(service_name))
  @result = r.create(by: user)
end
