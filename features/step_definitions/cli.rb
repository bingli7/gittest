## Put here steps that are mostly cli specific, e.g new-app
When /^I run the :(.*?) client command$/ do |yaml_key|
  yaml_key.sub!(/^:/,'')
  @result = user.cli_exec(yaml_key.to_sym, {})
end

When /^I run the :([a-z_]*?)( background)? client command with:$/ do |yaml_key, background, table|
  if background
    @result = user.cli_exec(
      yaml_key.to_sym,
      opts_array_process(table.raw) << [ :_background, true ]
    )
    @bg_rulesresults << @result
    @bg_processes << @result[:process_object]
  else
    @result = user.cli_exec(yaml_key.to_sym, opts_array_process(table.raw))
  end
end

When /^I run the :([a-z_]*?)( background)? admin command$/ do |yaml_key, background|
  step "I run the :#{yaml_key}#{background} admin command with:",
    table([["dummy"]])
end

When /^I run the :([a-z_]*?)( background)? admin command with:$/ do |yaml_key, background, table|
  ensure_admin_tagged
  opts = table.raw == [["dummy"]] ? [] : opts_array_process(table.raw)

  if background
    @result = env.admin_cli_executor.exec(
      yaml_key.to_sym,
      opts << [ :_background, true ]
    )
    @bg_rulesresults << @result
    @bg_processes << @result[:process_object]
  else
    @result = env.admin_cli_executor.exec(yaml_key.to_sym, opts)
  end
end

# there is no such thing as app in OpenShift but there is a command new-app
#   in the cli that logically represents an app - creating/deploying different
#   pods, services, etc.; There is a discussion coing on to rename and refactor
#   the funcitonality. Not sure that goes anywhere but we could adapt this
#   step for backward compatibility if needed.
Given /^I create a new application with:$/ do |table|
  step 'I run the :new_app client command with:', table
end

# instead of writing multiple steps, this step does this in one go:
# 1. download file from JSON/YAML URL
# 2. replace any path with given value from table
# 3. runs `oc create` command over the resulting file
When /^I run oc create( as admin)? (?:over|with) #{QUOTED} replacing paths:$/ do |admin, file, table|
  if file.include? '://'
    step %Q|I download a file from "#{file}"|
    resource_hash = YAML.load(@result[:response])
  else
    resource_hash = YAML.load_file(expand_path(file))
  end

  # replace paths from table
  table.raw.each do |path, value|
    eval "resource_hash#{path} = YAML.load value"
    # e.g. resource["spec"]["nfs"]["server"] = 10.10.10.10
    #      resource["spec"]["containers"][0]["name"] = "xyz"
  end
  resource = resource_hash.to_json
  logger.info resource

  if admin
    ensure_admin_tagged
    @result = self.admin.cli_exec(:create, {f: "-", _stdin: resource})
  else
    @result = user.cli_exec(:create, {f: "-", _stdin: resource})
  end
end

# instead of writing multiple steps, this step does this in one go:
# 1. download file from URL
# 2. load it as an ERB file with the cucumber scenario variables binding
# 3. runs `oc create` command over the resulting file
When /^I run oc create( as admin)? over ERB URL: #{HTTP_URL}$/ do |admin, url|
  step %Q|I download a file from "#{url}"|

  # overwrite with ERB loaded content
  loaded = ERB.new(File.read(@result[:abs_path])).result binding
  File.write(@result[:abs_path], loaded)
  if admin
    ensure_admin_tagged
    @result = self.admin.cli_exec(:create, {f: @result[:abs_path]})
  else
    @result = user.cli_exec(:create, {f: @result[:abs_path]})
  end
end

#@param file
#@notes Given a remote (http/s) or local file, run the 'oc process'
#command followed by the 'oc create' command to save space
When /^I process and create #{QUOTED}$/ do |file|
 step 'I process and create:', table([["f", file]])
end

# process file/url with parameters, then feed into :create
When /^I process and create:$/ do |table|
  # run the process command, then pass it in as stdin to 'oc create'
  process_opts = opts_array_process(table.raw)
  @result = user.cli_exec(:process, process_opts)
  if @result[:success]
    @result = user.cli_exec(:create, {f: "-", _stdin: @result[:stdout]})
  end
end

# this step basically wraps around the steps we use for simulating 'oc edit <resource_name'  which includes the following steps:
# #   1.  When I run the :get client command with:
#       | resource      | dc |
#       | resource_name | hooks |
#       | o             | yaml |
#     And I save the output to file>hooks.yaml
#     And I replace lines in "hooks.yaml":
#       | 200 | 10 |
#       | latestVersion: 1 | latestVersion: 2 |
#     When I run the :replace client command with:
#       | f      | hooks.yaml |
#  So the output file name will be hard-coded to 'tmp_out.yaml', we still need to
#  supply the resouce_name and the lines we are replacing
Given /^I replace resource "([^"]+)" named "([^"]+)"(?: saving edit to "([^"]+)")?:$/ do |resource, resource_name, filename,table |
  filename = "edit_resource.yaml" if filename.nil?
  step %Q/I run the :get client command with:/, table(%{
    | resource | #{resource} |
    | resource_name |  #{resource_name} |
    | o | yaml |
    })
  step %Q/the step should succeed/
  step %Q/I save the output to file>#{filename}/
  step %Q/I replace content in "#{filename}":/, table
  step %Q/I run the :replace client command with:/, table(%{
    | f | #{filename} |
    })
end

Given /^I terminate last background process$/ do
  if @bg_processes.last.finished?
    raise "last process already finished: #{@bg_processes.last}"
  end

  @bg_processes.last.kill_tree
  @result = @bg_processes.last.result
end
