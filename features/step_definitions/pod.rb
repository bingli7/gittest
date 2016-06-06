Given /^a pod becomes ready with labels:$/ do |table|
  labels = table.raw.flatten # dimentions irrelevant
  pod_timeout = 10 * 60
  ready_timeout = 15 * 60

  @result = CucuShift::Pod.wait_for_labeled(*labels, user: user, project: project, seconds: pod_timeout)

  if @result[:matching].empty?
    # logger.info("Pod list:\n#{@result[:response]}")
    # logger.error("Waiting for labeled pods futile: #{labels.join(",")}")
    raise "See log, waiting for labeled pods futile: #{labels.join(',')}"
  end

  cache_pods(*@result[:matching])

  @result = pod.wait_till_ready(user, ready_timeout)

  unless @result[:success]
    logger.error(@result[:response])
    raise "#{pod.name} pod did not become ready"
  end
end

Given /^the pod(?: named "(.+)")? becomes ready$/ do |name|
  ready_timeout = 15 * 60
  @result = pod(name).wait_till_ready(user, ready_timeout)

  unless @result[:success]
    logger.error(@result[:response])
    raise "#{pod.name} pod did not become ready"
  end
end

Given /^the pod(?: named "(.+)")? is present$/ do |name|
  present_timeout = 5 * 60
  @result = pod(name).wait_to_appear(user, present_timeout)

  unless @result[:success]
    logger.error(@result[:response])
    raise "#{pod.name} pod was never present"
  end
end

Given /^the pod(?: named "(.+)")? status becomes :([^\s]*?)$/ do |name, status|
  status_timeout = 15 * 60
  @result = pod(name).wait_till_status(status.to_sym, user, status_timeout)

  unless @result[:success]
    logger.error(@result[:response])
    raise "#{pod.name} pod did not become #{status}"
  end
end

# for a rc that has multiple pods, oc describe currently doesn't support json/yaml output format, so do 'oc get pod' to get the status of each pod
# this step is deprecated due to not having clear semantics
Given /^all pods in the project are ready$/ do
  pods = project.pods(by:user)
  logger.info("Number of pods: #{pods.count}")
  pods.each do | pod |
    cache_pods(pod)
    res = pod.wait_till_status(CucuShift::Pod::SUCCESS_STATUSES, user, 15*60)

    unless res[:success]
      raise "pod #{self.pod.name} did not reach expected status"
    end
  end
end

Given /^([0-9]+) pods become ready with labels:$/ do |count, table|
  labels = table.raw.flatten # dimentions irrelevant
  pod_timeout = 10 * 60
  ready_timeout = 15 * 60
  num = Integer(count)

  # TODO: make waiting a single step like for PVs and PVCs
  @result = CucuShift::Pod.wait_for_labeled(*labels, count: num,
                       user: user, project: project, seconds: pod_timeout)

  if !@result[:success] || @result[:matching].size < num
    logger.error("Wanted #{num} but only got '#{@result[:matching].size}' pods labeled: #{labels.join(",")}")
    raise "See log, waiting for labeled pods futile: #{labels.join(',')}"
  end

  cache_pods(*@result[:matching])

  # keep last waiting @result as the @result for knowing how pod failed
  @result[:matching].each do |pod|
    @result = pod.wait_till_status(CucuShift::Pod::SUCCESS_STATUSES, user, 900)

    unless @result[:success]
      raise "pod #{pod.name} did not reach expected status"
    end
  end
end

# useful for waiting the deployment pod to die and complete
# Called without the 'regardless...' parameter ir checks that pod reaches a
#   ready status, then somehow dies. With the parameter it just makes sure
#   pod os not there regardless of its current status.
Given /^I wait for the pod(?: named "(.+)")? to die( regardless of current status)?$/ do |name, ignore_status|
  ready_timeout = 15 * 60
  @result = pod(name).wait_till_ready(user, ready_timeout) unless ignore_status
  if ignore_status || @result[:success]
    @result = pod(name).wait_till_not_ready(user, ready_timeout)
  end
  unless @result[:success]
    logger.error(@result[:response])
    raise "#{pod.name} pod did not die"
  end
end

Given /^all existing pods die with labels:$/ do |table|
  labels = table.raw.flatten # dimentions irrelevant
  timeout = 10 * 60
  start_time = monotonic_seconds

  current_pods = CucuShift::Pod.get_matching(user: user, project: project,
                    get_opts: {l: selector_to_label_arr(*labels)})

  current_pods.each do |pod|
    @result =
      pod.wait_till_not_ready(user, timeout - monotonic_seconds + start_time)
    unless @result[:success]
      raise "pod #{pod.name} did not die within allowed time"
    end
  end
end

# args can be a table where each cell is a command or an argument, or a
#   multiline string where each line is a command or an argument
When /^I execute on the(?: "(.+?)")? pod:$/ do |pod_name, raw_args|
  if raw_args.respond_to? :raw
    # this is table, we don't mind dimentions used by user
    args = raw_args.raw.flatten
  else
    # multi-line string; useful when piping is needed
    args = raw_args.split("\n").map(&:strip)
  end

  @result = pod(pod_name).exec(*args, as: user)
end

# wrapper around  oc logs, keep executing the command until we have an non-empty response
# There are few occassion that the 'oc logs' cmd returned empty response
#   this step should address those situations
Given /^I collect the deployment log for pod "(.+)" until it disappears$/ do |pod_name|
  opts = {resource_name: pod_name}
  res_cache = {}
  res = {}
  seconds = 15 * 60   # just put a timeout so we don't hang there indefintely
  success = wait_for(seconds) {
    res = user.cli_exec(:logs, **opts)
    if res[:response].include? 'not found'
      # the deploy pod has disappeared which mean we are done waiting.
      true
    else #
      res_cache = res
      false
    end
  }
  res_cache[:success] = success
  @result  = res_cache
end

