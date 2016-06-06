require 'yaml'

Given /^the#{OPT_QUOTED} PVC becomes #{SYM}(?: within (\d+) seconds)?$/ do |pvc_name, status, timeout|
  timeout = timeout ? timeout.to_i : 30
  @result = pvc(pvc_name).wait_till_status(status.to_sym, user, timeout)

  unless @result[:success]
    raise "PVC #{pvc_name} never reached status: #{status}"
  end
end

Given /^([0-9]+) PVCs become #{SYM}(?: within (\d+) seconds)? with labels:$/ do |count, status, timeout, table|
  labels = table.raw.flatten # dimentions irrelevant
  timeout = timeout ? timeout.to_i : 60
  status = status.to_sym
  num = Integer(count)

  @result = CucuShift::PersistentVolumeClaim.wait_for_labeled(*labels,
              project: project, count: num, user: user, seconds: timeout) do |pvc, pvc_hash|
    pvc.status?(user: user, status: status, cached: true)[:success]
  end

  @pvcs.reject! { |pvc| @result[:matching].include? pvc }
  @pvcs.concat @result[:matching]

  if !@result[:success] || @result[:matching].size != num
    logger.error("Wanted #{num} but got '#{@result[:matching].size}' PVCs labeled: #{labels.join(",")}")
    logger.info @result[:response]
    raise "See log, waiting for labeled PVCs futile: #{labels.join(',')}"
  end
end
