require 'yaml'

require 'common'
require_relative 'token'
require_relative 'project'

module CucuShift
  # @note represents an OpenShift environment user account
  class User
    include Common::Helper

    attr_reader :name, :env, :rest_preferences

    # @param token [String] auth bearer token in plain string format
    # @param name [String] username (optional if we auth with token)
    # @param password [String] password if we have such for the user
    # @param env [CucuShift::Environment] the test environment user belongs to
    # @note user needs either token or password and username
    def initialize(name: nil, password: nil, token: nil, env:)
      @name = name.freeze if name
      @env = env
      @password = password.freeze if password
      @rest_preferences = {}
      @tokens = []

      add_str_token(token, protect: true) if token

      if @tokens.empty? && (@name.nil? || @password.nil?)
        raise "to initialize user we need a token or username and password"
      end
    end

    def name
      return @name if @name

      ## obtain username by the token
      unless cached_tokens[0]
        raise "somehow user has no name and no token defined"
      end

      res = get_self

      if res[:success] && res[:props] && res[:props][:name]
        @name = res[:props][:name]
        return @name
      else
        raise "could not obtain username with token #{cached_tokens[0]}: #{res[:response]}"
      end
    end

    def get_self
      #env.rest_request_executor.exec(user: self, auth: :bearer_token,
      #                                           req: :get_user,
      #                                           opts: {username: '~'})
      rest_request(:get_user, username: '~')
    end

    # @return true if we know user's password
    def password?
      return !! @password
    end

    def to_s
      "#{@name || "unknown"}@#{env.opts[:key]}"
    end

    def password
      if @password
        return @password
      else
        # most likely we initialized user with token only so we don't know pswd
        raise "user '#{name}' initialized without a password"
      end
    end

    # add a token in plain string format to cached tokens
    # @param token [String] the bearer token
    def add_str_token(str_token, protect: false)
      # we just guess token validity of one day, it should be persisting
      #   long enough to conduct testing anyway; I don't see reason to do the
      #   extra step getting validity from API
      unless cached_tokens.find { |t| t.token == str_token }
        cached_tokens << Token.new(user: self, token: str_token,
                                   valid: Time.now + 24 * 60 * 60)
        cached_tokens.last.protect if protect
      end

    end

    private def cli_executor
      env.cli_executor
    end

    def cli_exec(key, opts={})
      cli_executor.exec(self, key, opts)
    end

    def webconsole_executor
      env.webconsole_executor.executor(self)
    end

    def webconsole_exec(action, opts={})
      env.webconsole_executor.run_action(self, action, **opts)
    end

    # execute a rest request as this user
    # @param [Symbol] req the request to be executed
    # @param [Hash] opts the options needed for particular request
    # @note to set auth type, add :rest_default_auth to @rest_preferences
    def rest_request(req, **opts)
      env.rest_request_executor.exec(user: self, req: req, opts: opts)
    end

    private def rest_request_executor
      env.rest_request_executor
    end

    # will return user known oauth tokens
    # @note we do not encourage caching everything into this test framework,
    #   rather prefer discovering online state. Token is different though as
    #   without a token, one is unlikely to be able to perform any other
    #   operation. So we need to have at least limited token caching.
    def cached_tokens
      return @tokens
    end

    def get_bearer_token(**opts)
      return cached_tokens.first if cached_tokens.size > 0
      return Token.new_oauth_bearer_token(self) # this should add token to cache
    end

    def clean_projects
      logger.info "cleaning-up user #{name} projects"

      ## make sure we don't delete special projects due to wrong permissions
      #  also make sure we don't hit policy cache incoherence
      only_safe_projects = wait_for(30, interval: 5) {
        projects = projects()
        return if projects.empty?
        project_names = projects.map(&:name)
        (project_names & Project::SYSTEM_PROJECTS).empty?
      }
      unless only_safe_projects
        raise "system projects visible to user #{name}, clean-up too dangerous"
      end

      res = cli_exec(:delete, object_type: "projects", object_name_or_id: '--all')
      # we don't need to check exit status, but some time is needed before
      #   project deleted status propagates properly
      unless res[:response].include? "No resource"
        logger.info("waiting up to 30 seconds for user clean-up to take place")
        visible_projects = []
        success = wait_for(30) { (visible_projects = projects()).empty? }
        unless success
          logger.warn("user #{name} has visible projects after clean-up, beware: #{visible_projects.map(&:name)}")
        end
      end
    end

    def clean_up_on_load
      # keep project clean first as it can also catch policy cache incoherence
      # see https://bugzilla.redhat.com/show_bug.cgi?id=1337096
      clean_projects
    end

    # @return [Array<Project>]
    def projects
      Project.list(user: self, get_opts: {_quiet: true})
    end

    def clean_up
      clean_up_on_load
      # best effort remove any non-protected tokens
      cached_tokens.reverse_each do |token|
        token.delete(uncache: true) unless token.protected?
      end
    end
  end
end
