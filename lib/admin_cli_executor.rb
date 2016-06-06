require 'rules_command_executor'

module CucuShift
  class AdminCliExecutor
    include Common::Helper

    attr_reader :env, :opts

    RULES_DIR = File.expand_path(HOME + "/lib/rules/cli")

    def initialize(env, **opts)
      @env = env
      @opts = opts
    end

    def exec(key, **opts)
      raise
    end

    private def version
      return opts[:admin_cli_version]
      # this method needs to be overriden per executor to find out version
    end

    # @param [String, :admin, nil] user user to execute oadm command as
    private def version_on_host(user, host)
      # return user requested version if specified
      return version if version

      res = host.exec_as(user, "oadm version")
      unless res[:success]
        logger.error(res[:response])
        raise "cannot execute on host #{host.hostname} as admin"
      end
      return opts[:admin_cli_version] = res[:response].match(/^oadm v(.+)$/).captures[0]
    end

    private def rules_version(str_version)
      return str_version.split('.')[1]
    end

    def clean_up
    end
  end

  # execites admin commands as admin on first master host
  # @deprecated Please use [MasterKubeconfigLocalAdminCliExecutor] instead
  #   or another executor running on localhost. Remote excutors will fail for
  #   scenarios that run commands to read for local files
  class MasterOsAdminCliExecutor < AdminCliExecutor
    ADMIN_USER = :admin # might use a config variable for that

    def host
      env.master_hosts.first
    end

    def executor
      @executor ||= RulesCommandExecutor.new(
          host: host,
          user: ADMIN_USER,
          rules: File.expand_path(
                RULES_DIR +
                "/" +
                 rules_version(version_on_host(ADMIN_USER, host)) + ".yaml"
          )
      )
    end

    # @param [Hash, Array] opts the options to pass down to executor
    def exec(key, opts={})
      executor.run(key, opts)
    end

    def clean_up
      @executor.clean_up if @executor
      super
    end
  end

  # execites admin commands with downloaded .kube/config from first master
  class MasterKubeconfigLocalAdminCliExecutor < AdminCliExecutor
    def master_host
      env.master_hosts.first
    end

    def executor
      @executor ||= RulesCommandExecutor.new(
          host: localhost,
          user: nil,
          rules: File.expand_path(
                RULES_DIR +
                "/" +
                 rules_version(version_on_host(nil, localhost)) + ".yaml"
          )
      )
    end

    private def cli_opts
      return @cli_opts if @cli_opts
      config = "#{env.opts[:key]}_admin.kubeconfig"
      config = localhost.absolute_path config

      res = master_host.exec_as(:admin, "cat /root/.kube/config", quiet: true)
      if res[:success]
        # host_pattern = '(?:' << env.master_hosts.map{|h| Regexp.escape h.hostname).join('|') << ')'
        # server = res[:stdout].scan(/^\s*server:\s.*#{host_pattern}.*$/)[0]
        # raise "cannot find master in remote admin kubeconfig" unless server
        # File.write(config, res[:stdout].gsub(/^\s*server:\s.*$/) {server} )
        config_str = res[:stdout].gsub(/^(\s*server:)\s.*$/) {
          $1 + " " + env.api_endpoint_url
        }
        logger.plain config_str, false
        raise "wrong config" unless config_str.include? "server: #{env.api_endpoint_url}"
        File.write(config, config_str)
      else
        logger.error(res[:response])
        raise "error running command on master #{master.host.hostname} as admin, see log"
      end

      return @cli_opts = {config: config} # yes, assignment
    end

    # @param [Hash, Array] opts the options to pass down to executor
    def exec(key, opts={})
      executor.run(key, Common::Rules.merge_opts(cli_opts,opts))
    end

    def clean_up
      @executor.clean_up if @executor
      @cli_opts = nil # kubeconfig removed from workspace between scenarios
      super
    end
  end
end
