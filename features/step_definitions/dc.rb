#### deployConfig related steps
# Given /^I wait until deployment (?: "(.+)")? matches version "(.+)"$/ do |resource_name, version|
#   ready_timeout = 5 * 60
#   resource_name = resource_name + "-#{version}"
#   rc(resource_name).wait_till_ready(user, ready_timeout)
# end

Given /^I wait until the status of deployment "(.+)" becomes :(.+)$/ do |resource_name, status|
  ready_timeout = 10 * 60
  dc(resource_name).wait_till_status(status.to_sym, user, ready_timeout)
end

# restore the selected dc in teardown by getting current deployment and do:
#   'oc rollback <dc_name> --to-version=<saved_good_version>'
Given /^default (router|docker-registry) deployment config is restored after scenario$/ do |resource|
  ensure_destructive_tagged
  _admin = admin
  _project = project("default", switch: false)
  # first we need to save the current version
  _rc = CucuShift::ReplicationController.get_labeled(
    resource,
    user: _admin,
    project: _project
  ).max_by {|rc| rc.props[:created]}

  raise "no matching rcs found" unless _rc
  version = _rc.props[:annotations]["openshift.io/deployment-config.latest-version"]
  unless _rc.ready?(user: :admin, cached: true)
    raise "latest rc version #{version} is bad"
  end

  teardown_add {
    @result = _admin.cli_exec(:rollback, deployment_name: resource, to_version: version, n: _project.name)
    raise "Cannot restore #{resource}" unless @result[:success]
    latest_version = @result[:response].match(/^#(\d+)/)[1]
    rc_name = resource + "-" + latest_version
    @result = rc(rc_name, _project).wait_till_ready(_admin, 900)
    raise "#{rc_name} didn't become ready" unless @result[:success]
  }
end
