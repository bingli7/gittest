require 'yaml'
require 'find'

require 'collections'
require 'common'
require 'rules_common'
require_relative 'web4cucumber'

module CucuShift
  class WebConsoleExecutor
    include Common::Helper

    attr_reader :env

    # if we need multiple rules version for ose/online/origin/etc, we can
    #   set a configuration option to read rules from different subdirs
    RULES_DIR = File.expand_path(HOME + "/lib/rules/web/console") + "/"

    def initialize(env, **opts)
      @env = env
      @opts = opts
      @executors = {}
      @rules = nil # use rules cache to space a few milliseconds
    end

    def executor(user)
      return @executors[user.name] if @executors[user.name]

      rulez = @rules || RULES_DIR

      @executors[user.name] = Web4Cucumber.new(
        logger: logger,
        base_url: env.web_console_url,
        rules: rulez
      )

      # if we don't have cached rules, do it now
      @rules ||= Collections.deep_freeze(@executors[user.name].rules)

      return @executors[user.name]
    end

    def login(user)
      if user.password?
        return executor(user).run_action(:login,
                                         username: user.name,
                                         password: user.password)
      else
        # looks like we use token only user, lets try to hack our way in
        # res = user.get_self
        # if res[:success]
          return executor(user).run_action(:login_token,
                                           # user: res[:response].chomp,
                                           token: user.get_bearer_token.token
                                          )
        # else
        #  raise "error getting user API object: res[:response]"
        # end
      end
    end

    def run_action(user, action, **opts)
      login_actions = [ :login, :login_token ]

      if action == :logout && !user.password?
        raise "be careful to not logout while user defined only by token"
      end

      # login automatically on first browser use unless `_nologin` option given
      if !opts.delete(:_nologin) && executor(user).is_new? &&
                                    !login_actions.include?(action)
        res = login(user)
        unless res[:success]
          logger.error "login to web console failed:\n" + res[:response]
          return res
        end
      end

      # execute actual action requested
      return executor(user).run_action(action, **opts)
    end

    def clean_up
      @executors.values.each(&:finalize)
      @executors.clear
    end
  end
end
