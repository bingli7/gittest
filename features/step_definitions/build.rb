Given /^the "([^"]*)" build was created$/ do |build_name|
  @result = build(build_name).wait_to_appear(user, 60)

  unless @result[:success]
    raise "build #{build_name} never created"
  end
end

# success when build finish regardless of completion status
Given /^the "([^"]*)" build finishe(?:d|s)$/ do |build_name|
  @result = build(build_name).wait_till_finished(user, 60*15)

  unless @result[:success]
    raise "build #{build_name} never finished"
  end
end

# success if build completed successfully
Given /^the "([^"]*)" build complete(?:d|s)$/ do |build_name|
  @result = build(build_name).wait_till_completed(user, 60*15)

  unless @result[:success]
    if [:failed, :error].include? @result[:matched_status]
      user.cli_exec(:logs, resource_name: "build/#{build_name}")
      raise "build #{build_name} failed"
    end 
    raise "build #{build_name} never completed"
  end
end

# success if build completed with a failure
Given /^the "([^"]*)" build fail(?:ed|s)$/ do |build_name|
  @result = build(build_name).wait_till_failed(user, 60*15)

  unless @result[:success]
    raise "build #{build_name} completed with success or never finished"
  end
end

# success if build was cancelled
Given /^the "([^"]*)" build was cancelled$/ do |build_name|
  @result = build(build_name).wait_till_cancelled(user, 60*15)

  unless @result[:success]
    raise "build #{build_name} was not canceled"
  end
end

Given /^the "([^"]*)" build becomes #{SYM}$/ do |build_name, status|
  wait_time_out = 10 * 60
  @result = build(build_name).wait_till_status(status.to_sym, user, wait_time_out)

  unless @result[:success]
    raise "build #{build_name} never became #{status}"
  end
end

Then(/^I save pruned builds in the "([^"]*)" project into the :([^\s]*?) clipboard$/) do |project_name, cb_name|
  project = self.project(project_name)
  # lookbehind does not support quantifiers and jruby no support of \K
  build_names = @result[:response].scan(%r%(?<=^#{Regexp.escape(project.name)})\s+[^\s]*$%)
  builds = build_names.map { |bn|
    CucuShift::Build.new(name: bn.strip, project: project)
  }
  cb[cb_name] = builds
end

Given /^I save project builds into the :([^\s]*?) clipboard$/ do |cb_name|
  cb[cb_name] = project.get_builds(by: user)
end

Then /^the project should contain no builds$/ do
  builds = project.get_builds(by: user)
  unless builds.empty?
    raise "#{builds.size} builds present in the #{project.name} project"
  end
end
