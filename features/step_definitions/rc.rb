### replicationController related steps

# to reliably wait for all the replicas to be come ready, we do
# 'oc get rc <rc_name>' and wait until the spec['replicas'] == status['replicas']
Given /^I wait until replicationController "(.+)" is ready$/ do |rc_name |
  ready_timeout = 15 * 60
  @result = rc(rc_name).wait_till_ready(user, ready_timeout)

  raise "replication controller #{rc.name} never became ready" unless @result[:success]
end

# Given /^I wait until the status of replication controller "(.+)" becomes :(.+)$/ do |resource_name, status|
#   ready_timeout = 10 * 60
#   rc(resource_name).wait_till_status(status.to_sym, user, ready_timeout)
# end

Given /^I wait until number of(?: "(.*?)")? replicas match "(\d+)" for replicationController "(.+)"$/ do |state, number, rc_name|
ready_timeout = 300
  state = :running if state.nil?
  @result = rc(rc_name).wait_till_replica_count_match(
    user: user,
    state: state,
    seconds: ready_timeout,
    replica_count: number.to_i
  )

  unless @result[:success]
    raise "desired replica count not reached within timeout"
  end
end
