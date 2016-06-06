When /^I give project (.+?) role to the(?: (.+?))? (user|service account)$/ do |role_name, user_name, user_type|
  case user_type
  when "user"
    user_name=user(word_to_num(user_name), switch: false).name
  when "service account"
    user_name=service_account(user_name, switch: false).name
  else
    raise "unknown user type: #{user_type}"
  end

  user.cli_exec(
    :policy_add_role_to_user,
    role: role_name,
    user_name: user_name,
    n: project.name
  )
end

When /^I remove project (.+?) role from the(?: (.+))? (user|service account)$/ do |role_name, user_name, user_type|
  case user_type
  when "user"
    user_name=user(word_to_num(user_name), switch: false).name
  when "service account"
    user_name=service_account(user_name, switch: false).name
  else
    raise "unknown user type: #{user_type}"
  end

  user.cli_exec(
    :policy_remove_role_from_user,
    role: role_name,
    user_name: user_name,
    n: project.name
  )
end

Given /^(the [a-z]+) user is cluster-admin$/ do |which_user|
  ensure_admin_tagged
  step %Q{cluster role "cluster-admin" is added to the "#{which_user}" user}
end

Given /^cluster role #{QUOTED} is (added to|removed from) the #{QUOTED} (user|group|service account)$/ do |role, op, which, type|
  ensure_admin_tagged
  _admin = admin

  case type
  when "group"
    _add_command = :oadm_add_cluster_role_to_group
    _remove_command = :oadm_remove_cluster_role_from_group
    _opts = {role_name: role, group_name: which}
  when "user", "service account"
    if type == "user"
      _user_name = user(word_to_num(which), switch: false).name
    else
      _user_name = service_account(which, switch: false).name
    end

    _add_command = :oadm_add_cluster_role_to_user
    _remove_command = :oadm_remove_cluster_role_from_user
    _opts = {role_name: role, user_name: _user_name}
  else
    raise "what is this subject type #{type}?!"
  end

  case op
  when "added to"
    _command = _add_command
    _teardown_command = _remove_command
  when "removed from"
    _command = _remove_command
    _teardown_command = _add_command
  else
    raise "unknown policy operation #{op}"
  end

  # we reattempt multiple times to workaround races where cluster policy is
  #   concurrently changed by another test executor
  wait_for(60, interval: 5) {
    @result = _admin.cli_exec(_command, **_opts)
    @result[:success]
  }
  if @result[:success]
    teardown_add {
      _res = nil
      wait_for(60, interval: 5) {
        _res = _admin.cli_exec(_teardown_command, **_opts)
        _res[:success]
      }
      raise "could not restore role of #{which} #{type}" unless _res[:success]
    }
  else
    raise "could not give #{which} #{type} the #{role} role"
  end
end
