# you use "second", "third", "default", etc. user
Given /^I switch to(?: the)? ([a-z]+) user$/ do |who|
  user(word_to_num(who))
end

# user full or short service account name, e.g.:
# system:serviceaccount:project_name:acc_name
# acc_name
Given /^I switch to the (.+) service account$/ do |who|
  @user = service_account(who)
end

Given /^I switch to cluster admin pseudo user$/ do
  ensure_admin_tagged
  @user = admin
end

Given /^I create the serviceaccount "([^"]*)"$/ do |name|
  sa = service_account(name)
  @result = sa.create(by: user)

  raise "could not create service account #{name}" unless @result[:success]
end

Given /^I find a bearer token of the(?: (.+?))? service account$/ do |acc|
  service_account(acc).load_bearer_tokens(by: user)
end
