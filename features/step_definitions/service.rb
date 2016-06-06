Given(/^I use the "([^"]*)" service$/) do |service_name|
  service(service_name)
end

Given /^I reload the(?: "([^"]*)")? service$/ do |service_name|
  @result = service(service_name).get_checked(user: user)
end

# check the service has a ready pod
Given(/^I wait for the(?: "([^"]*)")? service to become ready$/) do |name|
  service(name) if name
  service_timeout = 2*60

  @result = service.wait_to_appear(user, service_timeout)
  unless @result[:success]
    logger.error(@result[:response])
    raise "service #{name} did not appear after #{service_timeout} seconds"
  end

  step 'a pod becomes ready with labels:',
    table('|' + selector_to_label_arr(*service.selector(user: user)).join("|") + '|')
end

Given(/^I wait for the(?: "([^"]*)")? service to be created$/) do |name|
  @result = service(name).wait_to_appear(user, 60)

  unless @result[:success]
    raise "timeout waiting for service #{name} to be created"
  end
end
