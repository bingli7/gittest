require 'yaml'

require 'rules_command_executor'

module CucuShift
  class CliExecutor
    include Common::Helper

    RULES_DIR = File.expand_path(HOME + "/lib/rules/cli")
    LOGIN_TIMEOUT = 20 # seconds

    attr_reader :opts

    def initialize(env, **opts)
      @opts = opts
    end

    # @param [CucuShift::User] user user to execute command with
    # @param [Symbol] key command key
    # @param [Hash] opts command options
    # @return [CucuShift::ResultHash]
    def exec(user, key, **opts)
      raise
    end

    private def version
      return opts[:cli_version]
      # this method needs to be overwriten per executor to find out version
    end

    # get `oc` version on some host running as some username
    # @param user [String] string username
    # @param host [CucuShift::Host] the host to execute command on
    # @return [String] version string
    def self.get_version_for(user, host)
      res = host.exec_as(user, "oc version")
      raise "cannot execute on host #{host.hostname} as user #{user}" unless res[:success]
      return res[:response].scan(/^os?c v(.+)$/)[0][0]
    end

    # work in progress, we need to see how versionning goes forward;
    #   hopefully we get stable mapping between ose and origin cli version at
    #   some point
    private def rules_version(str_version)
      v = str_version.split('.')
      if v.first == '3' && v[1..2].all? {|e| e =~ /^[0-9]+$/} && v[3]
        # version like v3.0.0.0-32-g3ae1d27, i.e. return version 0
        return str_version.split('.')[1]
      else
        # version like v1.0.2, i.e. return version 0
        return (Integer(v[0]) - 1).to_s
      end
    end

    def self.token_from_cli(user)
      res = user.cli_exec(:config_view, output: "yaml")
      unless res[:success]
        user.env.master_hosts[0].logger.error res[:response]
        raise "cannot read user configuration by: #{res[:instruction]}"
      end
      conf = YAML.load(res[:response])
      uhash = conf["users"].find{|u| u["name"].start_with?(user.name + "/")}
      return uhash["user"]["token"]
    end

    def clean_up
      # Should we remove any cli configfiles here? only in subclass when that
      #   is safe! Also we should not logout, because we clean-up tokens
      #   in User class where care is taken to avoid removing protected tokens.
    end
  end

  # execute cli commands on the first master machine as each user respectively
  #   it also does prior cert and token setup
  # @deprecated Please use [SharedLocalCliExecutor] instead
  #   or another executor running on localhost. Remote excutors will fail for
  #   scenarios that run commands to read for local files
  class MasterOsPerUserCliExecutor < CliExecutor
    def initialize(env, **opts)
      super
      @executors = {}
    end

    # @param [CucuShift::User] user user to execute command with
    # @return rules executor, separate one per user
    def executor(user)
      return @executors[user.name] if @executors[user.name]

      host = user.env.api_host
      version = version_for_user(user, host)
      executor = RulesCommandExecutor.new(host: host, user: user.name, rules: File.expand_path(RULES_DIR + "/" + rules_version(version) + ".yaml"))

      # make sure cli execution environment is setup for the user
      if user.cached_tokens.size == 0
        ## login with username and password and generate a bearer token
        executor.run(:logout, {}) # ignore outcome
        res = executor.run(:login, username: user.name, password: user.password, ca: "/etc/openshift/master/ca.crt", server: user.env.api_endpoint_url, _timeout: LOGIN_TIMEOUT)
      else
        ## login with existing token
        res = executor.run(:login, token: user.cached_tokens.first.token, ca: "/etc/openshift/master/ca.crt", server: user.env.api_endpoint_url)
      end
      unless res[:success]
        logger.error res[:response]
        raise "cannot login with command: #{res[:instruction]}"
      end

      # this executor is ready to be used, set it early to allow caching token
      @executors[user.name] = executor

      if user.cached_tokens.size == 0
        ## lets cache token obtained by username/password
        user.add_str_token(self.class.token_from_cli(user))
      end

      return executor
    end

    # @param user [CucuShift::User] the user we want to get version for
    # @param host [CucuShift::Host] the host we'll be running commands on
    private def version_for_user(user, host)
      # we assume all users will use same oc version;
      #   we may revisit later if needed
      opts[:cli_version] ||= CliExecutor.get_version_for(user.name, host)
    end

    # @param [Hash, Array] opts the options to pass down to executor
    def exec(user, key, opts={})
      executor(user).run(key, opts)
    end

    def clean_up
      # should we remove any cli configfiles here? maybe not..
      #   also we should not logout as we remove tokens in another manner
      #   and some tokens need to be protected to avoid losing them
      @executors.values.each(&:clean_up)
      @executors.clear
    end
  end

  class SharedLocalCliExecutor < CliExecutor
    attr_reader :host

    def initialize(env, **opts)
      super
      @host = localhost
      @logged_users = {}
    end

    # @return [RulesCommandExecutor] executor to run commands with
    private def executor
      return @executor if @executor

      # clean_old_config

      @executor = RulesCommandExecutor.new(host: host, user: nil, rules: File.expand_path(RULES_DIR + "/" + rules_version(version) + ".yaml"))
    end

    private def version
      opts[:cli_version] ||= CliExecutor.get_version_for(nil, localhost)
    end

    private def logged_users
      @logged_users
    end

    # clean-up .kube/config and .config/openshift/config
    #   we don't need this as long as we use the --config option
    #private def clean_old_config
    #  # this should also work on windows %USERPROFILE%/.kube
    #  host.delete('.kube', :r => true, :raw => true, :home => true)
    #  host.delete('.config/openshift', :r => true, :raw => true, :home => true)
    #end

    # current implementation is to run client commands with
    #   --config=<workdir>/<env key>_<user name>.kubeconfig to provide isolation
    #   between users running cli commands. Another option considered was
    #   --context=... but for this to work, we would have needed to execute
    #   a second cli command after any cli command to obtain last user context.
    #   And that has two issues - it is an overhead as well running simultaneous
    #   commands may cause race conditions.
    # @return [Hash] :config => "<workdir>/<env key>_<user name>.kubeconfig"
    private def user_opts(user)
      user_config = "#{user.env.opts[:key]}_#{user.name}.kubeconfig"
      user_config = host.absolute_path user_config # inside workdir

      # TODO: we may consider obtaining server CA chain and configuring it in
      #   instead of setting insecure SSL
      if user.cached_tokens.size == 0
        ## login with username and password and generate a bearer token
        res = executor.run(:login, username: user.name, password: user.password, insecure: "true", server: user.env.api_endpoint_url, config: user_config, _timeout: LOGIN_TIMEOUT)
      else
        ## login with existing token
        res = executor.run(:login, token: user.cached_tokens.first.token, insecure: "true", server: user.env.api_endpoint_url, config: user_config)
      end
      unless res[:success]
        logger.error res[:response]
        raise "cannot login with command: #{res[:instruction]}"
      end

      # success, set opts early to allow caching token
      logged_users[user.name] = {config: user_config}

      if user.cached_tokens.size == 0
        ## lets cache token if obtained by username/password
        user.add_str_token(self.class.token_from_cli(user))
      end

      return logged_users[user.name]
    end

    # @param [Hash, Array] opts the options to pass down to executor
    def exec(user, key, opts={})
      unless logged_users[user.name]
        user_opts(user)
      end

      executor.run(key, Common::Rules.merge_opts(logged_users[user.name],opts))
    end

    def clean_up
      @executor.clean_up if @executor
      logged_users.clear
      # do not remove local kube/openshift config file, workdir should be
      #   cleaned automatically between scenarios
      # we do not logout, see {CliExecutor#clean_up}
    end

  end
end
