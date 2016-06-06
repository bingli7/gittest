require 'singleton'

require 'log'
require 'configuration'
require 'environment_manager'
# should not require 'common'

module CucuShift
  # @note this class allows accessing global test execution state.
  #       Get the singleton object by calling Manager.instance.
  #       Manager should point always at the correct manager implementation.
  class DefaultManager
    include Singleton
    attr_accessor :world
    attr_reader :temp_resources, :test_case_manager, :custom_formatters

    def initialize
      @world = nil
      @temp_resources = []

      # # @browsers = ...

      # keep reference to CucuShift custom formatters so we can interact;
      #   at the moment we use to call #process_scenario_log from the test case
      #   manager to get hold on scenario log and artifacts at convenient time
      @custom_formatters = []
    end

    def clean_up
      @environments.clean_up if @environments
      @temp_resources.each(&:clean_up)
      @temp_resources.clear
      Host.localhost.clean_up
      @world = nil
    end
    alias after_scenario clean_up

    def at_exit
      # test_case_manager.at_exit # call in env.rb for visibility

      # perform clean up in case of abrupt interruption (ctrl+c)
      #   duplicate call after proper clean up in After hook should not hurt
      clean_up
    end

    def environments
      @environments ||= EnvironmentManager.new
    end

    def logger
      @logger ||= Logger.new
    end

    def conf
      @conf ||= Configuration.new
    end

    def self.conf
      self.instance.conf
    end

    def init_test_case_manager(cucumbler_config)
      tc_mngr = ENV['CUCUSHIFT_TEST_CASE_MANAGER'] || conf[:test_case_manager]
      tc_mngr = tc_mngr ? tc_mngr + '_tc_manager' : false
      if tc_mngr
        logger.info("Using #{tc_mngr} test case manager")
        tc_mngr_obj = conf.get_optional_class_instance(tc_mngr)

        ## register our test case manager
        @test_case_manager = tc_mngr_obj

        ## add our test case manager notifyer to the filter chain
        require 'test_case_manager_filter'
        cucumbler_config.filters << TestCaseManagerFilter.new(tc_mngr_obj)
      else
        # dummy test case manager to avoid no method defined errors
        @test_case_manager = Class.new do
          def method_missing(m, *args, &block); end
        end.new
      end
    end
  end

  # allow seamless use of manager outside Cucumber
  unless defined?(SkipCucuShiftManagerDefault) && SkipCucuShiftManagerDefault
    Manager ||= DefaultManager
  end
end
