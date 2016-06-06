# helper step to get default router subdomain
# will create a dummy route to obtain that
# somehow hacky in all regardsm hope we obtain a better mechanism after some time
Given /^I store default router subdomain in the#{OPT_SYM} clipboard$/ do |cb_name|
  raise "get router info as regular user" if CucuShift::ClusterAdmin === user

  cb_name = 'tmp' unless cb_name
  cb[cb_name] = env.router_default_subdomain(user: user,
                                             project: project(generate: false))
  logger.info cb[cb_name]
end

Given /^I store default router IPs in the#{OPT_SYM} clipboard$/ do |cb_name|
  raise "get router info as regular user" if CucuShift::ClusterAdmin === user

  cb_name = 'tmp' unless cb_name
  cb[cb_name] = env.router_ips(user: user, project: project(generate: false))
  logger.info cb[cb_name]
end
