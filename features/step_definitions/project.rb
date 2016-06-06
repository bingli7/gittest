Given /^I have a project$/ do
  # system projects should not be selected by default
  sys_projects = CucuShift::Project::SYSTEM_PROJECTS

  project = @projects.reverse.find {|p|
    p.visible?(user: user) &&
    p.active?(user: user, cached: 1) &&
    !sys_projects.include?(p.name)}
  if project
    # project does exist as visible is doing an actual query
    # also move project up the stack
    @projects << @projects.delete(project)
  else
    projects = (user.projects - sys_projects).select {|p|
      p.active?(user: user, cached: true)
    }
    if projects.empty?
      step 'I create a new project'
      unless @result[:success]
        logger.error(@result[:response])
        raise "unable to create project, see log"
      end
    else
      # at this point we know that project cache does not contain any user
      #   visible projects, so we can safely add user projects to cache
      @projects.concat projects
    end
  end
end

# try to create a new project with current user
When /^I create a new project(?: via (.*?))?$/ do |via|
  @result = CucuShift::Project.create(by: user, name: rand_str(5, :dns), _via: (via.to_sym if via))
  if @result[:success]
    @projects << @result[:project]
    @result = @result[:project].wait_to_be_created(user)
    unless @result[:success]
      logger.warn("Project #{@projects.last.name} not visible on server after create")
    end
    if via == "web"
      cache_browser(user.webconsole_executor)
      # switch automatically when creating via web
      step %Q/I use the "#{@projects.last.name}" project/
    end
  end
end

# create x number of projects
Given /^I create (\d+) new projects?$/ do |num|
  (1..Integer(num)).each {
    step 'I create a new project'
    unless @result[:success]
      logger.error(@result[:response])
      raise "unable to create project, see log"
    end
  }
end

# create a new project with user options,either via web or cli
When /^I create a project via (.+?) with:$/ do |via, table|
  opts = opts_array_to_hash(table.raw)
  @result = CucuShift::Project.create(by: user, name: rand_str(5, :dns), _via: (via.to_sym if via), **opts)
  if @result[:success]
    @projects << @result[:project]
    @result = @result[:project].wait_to_be_created(user)
    unless @result[:success]
      logger.warn("Project #{@projects.last.name} not visible on server after create")
    end
    if via == "web"
      cache_browser(user.webconsole_executor)
      step %Q/I use the "#{@projects.last.name}" project/
    end
  end
end

Given /^I use the "(.+?)" project$/ do |project_name|
  # this would find project in cache and move it up the stack
  # or create a new CucuShift::Project object and put it on top of stack
  project(project_name)

  # setup cli to have it as default project
  user.cli_exec(:project, project_name: project_name)
end

Given /^I imagine a project$/ do
  project(rand_str(5, :dns))
end

When /^admin creates a project$/ do
  ensure_admin_tagged

  project(rand_str(5, :dns))

  # first make sure we clean-up this project at the end
  _project = project # we need variable for the teardown proc
  teardown_add { @result = _project.delete(by: :admin) }

  # create with raw command to avoid safety project without admin user check in
  #   Project#create method
  @result = admin.cli_exec( :oadm_new_project,
                            project_name: project.name,
                            display_name: "Fancy project",
                            description: "OpenShift v3 rocks" )
end

When /^admin creates a project with:$/ do |table|
  ensure_admin_tagged

  opts = opts_array_process(table.raw)
  project_name = opts.find { |o| o[0] == :project_name }
  if project_name
    project_name = project_name[1]
  else
    project_name = rand_str(5, :dns)
    opts << [:project_name, project_name]
  end

  # first make sure we clean-up this project at the end
  _project = project(project_name) # we need variable for the teardown proc
  teardown_add { @result = _project.delete(by: :admin) }

  # create with raw command to avoid safety project without admin user check in
  #   Project#create method
  @result = admin.cli_exec( :oadm_new_project, opts)
end

When /^admin deletes the #{QUOTED} project$/ do |project_name|
  p = project(project_name)
  @result = p.delete(by: :admin)
  @projects.delete(p) if @result[:success]
end

# tries to delete last used project or a project with given name (if name given)
When /^I delete the(?: "(.+?)")? project$/ do |project_name|
  p = project(project_name)
  @result = project(project_name).delete(by: user)
  if @result[:success]
    @projects.delete(p)
    @result[:success] = p.wait_to_disappear(user)
    unless @result[:success]
      logger.warn("Project #{p.name} still visible on server after delete")
    end
  end
end

Given /^the(?: "(.+?)")? project is deleted$/ do |project_name|
  project_name = ' "' + project_name + '"' if project_name
  step "I delete the#{project_name} project"
  unless @result[:success]
    logger.error(@result[:response])
    raise "unable to delete project, see log"
  end
end

When(/^I delete all resources by labels:$/) do |table|
  @result = project.delete_all_labeled(*table.raw.flatten, by: user)
end

Then(/^the project should be empty$/) do
  @result = project.empty?(user: user)
  unless @result[:success]
    logger.error(@result[:response])
    raise "project not empty, see logs"
  end
end

When /^I get project ([-a-zA-Z_]+)(?: named "([^"]*)")?$/ do |resource, resource_name|
  @result = user.cli_exec(:get, resource: resource, resource_name: resource_name, n: project.name)
end

When /^I get project ([-a-zA-Z_]+) with labels:$/ do |resource, table|
  labels = table.raw.flatten
  @result = user.cli_exec(:get, resource: resource, n: project.name, l: labels)
end

When /^I get project ([-a-zA-Z_]+)(?: named "([^"]*)")? as (YAML|JSON)$/ do |resource, resource_name, format|
  @result = user.cli_exec(:get, resource: resource, resource_name: resource_name, n: project.name, o: format.downcase)
  step "the output is parsed as #{format}"
end
