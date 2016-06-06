## add our lib dir to load path
$LOAD_PATH << File.expand_path("#{__FILE__}/../../../lib")

ruby_ver = RUBY_VERSION.split('.')
if ruby_ver[0].to_i < 2 ||
    ruby_ver[0] == '2' && ruby_ver[1].to_i < 2 # ||
    # ruby_ver[0] == '2' && ruby_ver[1] == '2' && ruby_ver[2].to_i < 3

  raise "Ruby version earlier than 2.2 not supported"
end
if Cucumber::VERSION.split('.')[0].to_i < 2
  raise "Cucumber version < 2 not supported"
end

SkipCucuShiftManagerDefault = true # should manager.rb skip setting Manager

require 'common' # common code
require 'world' # our custom cucushift world
require 'log' # CucuShift::Logger
require 'manager' # our shared global state
require 'environment' # environment types classes
require 'debug'

## default course of action would be to update CucuShift files when
#  changes are needed but some features are specific to team and test
#  environment; lets allow customizing base classes by loading a separate
#  project tree
private_env_rb = File.expand_path(CucuShift::PRIVATE_DIR + "/env.rb")
require private_env_rb if File.exist? private_env_rb

World do
  # the new object created here would be the context Before and After hooks
  # execute in. So extend that class with methods you want to call.
  CucuShift::World.new
end

## while we can move everything inside World, lets try to outline here the
#    basic steps to have world ready to execute scenario
Before do |_scenario|
  setup_logger
  logger.info("=== Before Scenario: #{_scenario.name} ===")
  localhost.chdir
  self.scenario = _scenario

  ## raise inside block only if error can affect scenarios execution ##
  no_err, val = capture_error {
    # put other calls here to setup world according to tags, etc.
  }
  err = no_err ? nil : val

  manager.test_case_manager.signal(:finish_before_hook, scenario, err)
  hook_error!(err)
  logger.info("=== End Before Scenario: #{_scenario.name} ===")
  # dedup at these hooks broken as log goes to the next step and in Outlines
  #   it even ends up under one and the same step. Need to fix hooks somehow.
  # logger.dedup_start
end

## while we can move everything inside World, lets try to outline here the
#    basic steps that are run after each scenario execution
After do |_scenario|
  # logger.dedup_flush
  logger.info("=== After Scenario: #{_scenario.name} ===")
  self.scenario = _scenario # this is different object than in Before hook

  debug_in_after_hook

  ## raise inside block only if error can affect next scenarios execution ##
  no_err, val = capture_error {
    # World after_scenario clean up
    self.after_scenario
    # Manager after_scenario clean up
    manager.after_scenario
  }
  err = no_err ? nil : val

  manager.test_case_manager.signal(:finish_after_hook, scenario, err)
  hook_error!(err)
  logger.info("=== End After Scenario: #{_scenario.name} ===")
  CucuShift::Logger.reset_runtime # otherwise we lose output from test case mgmt
end

AfterStep do |scenario|
  # logger.dedup_flush
  # logger.dedup_start
end

AfterConfiguration do |config|
  CucuShift::Common::Setup.handle_signals
  CucuShift::Common::Setup.set_cucushift_home

  ## use default classes if these were not overriden by private ones
  CucuShift::Manager ||= CucuShift::DefaultManager
  CucuShift::World   ||= CucuShift::DefaultWorld

  ## install step failure debugging code
  if CucuShift::Manager.conf[:debug_failed_steps]
    CucuShift::Debug.step_fail_cucumber2
  end

  ## set test case manager if requested (adds a scenario filter as well)
  CucuShift::Manager.instance.init_test_case_manager(config)
end

at_exit do
  CucuShift::Logger.reset_runtime # otherwise we lose output
  CucuShift::Manager.instance.logger.info("=== At Exit ===")
  CucuShift::Manager.instance.test_case_manager.signal(:at_exit)
  CucuShift::Manager.instance.at_exit
end
