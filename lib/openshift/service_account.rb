require 'json'

require 'openshift/user'
require 'openshift/secret'

module CucuShift
  # represents OpenShift v3 Service account
  class ServiceAccount < User
    include Common::Helper

    # because this is a User and a User managed type at the same time, we have
    #   interference between #cli_exec methods in User and UserObjectHelper;
    #   lets workaround that
    alias user_cli_exec cli_exec
    include Common::UserObjectHelper
    alias _cli_exec cli_exec
    alias cli_exec user_cli_exec

    attr_reader :project, :props, :shortname

    # @param name [String] service name; we require this param to avoid
    #   implementing different `#name` method than what we have in User
    # @param project [CucuShift::Project] the project where account was created
    # @note e.g. ServiceAccount.new("system:serviceaccount:myproj:default", project)
    def initialize(name:, project:, token: nil)
      @project = project
      @props = {}

      # TODO: looks like a more proper User "intrerface" would be desirable
      #   instead of hacking around the regular User implementation
      super(name: name, token: (token || "fake"), env: project.env)
      @tokens.clear unless token # remove fake token
      normalize_name
    end

    undef webconsole_exec
    undef webconsole_executor

    # set name to the full string "system:serviceaccount:#{project}:#{name}"
    private def normalize_name
      if @name.include? ":"
        crap1, crap2, @shortname = @name.rpartition(":")
        @shortname.freeze
      else
        @shortname = @name.freeze
        @name = "system:serviceaccount:#{project.name}:#{@name}".freeze
      end
    end

    def create(by:)
      # payload
      p = {
        "kind" => "ServiceAccount", "apiVersion" => "v1",
        "metadata" => {
          "name" => shortname
        }
      }

      Tempfile.create(['payload','.json']) do |f|
        f.write(p.to_json)
        f.close
        return _cli_exec(as: by, key: :create, f: f.path, n: project.name)
      end
    end

    def get(user:)
      res = _cli_exec(as: user, key: :get, n: project.name,
                resource_name: shortname,
                resource: "serviceaccount",
                output: "yaml")

      if res[:success]
        res[:parsed] = YAML.load(res[:response])
        update_from_api_object(res[:parsed])
      end

      return res
    end
    alias reload get

    def get_checked(user:)
      res = get(user: user)
      if res[:success]
        update_from_api_object(res[:parsed])
      else
        logger.error(res[:response])
        raise "could not get service account, see log"
      end
      return res
    end

    def load_bearer_tokens(by:, reload: false)
      get_secrets(by: by, reload: reload).
        select { |s| s.bearer_token?(user: by) }.
        each { |s| add_str_token(s.token(user: by)) }
    end

    def get_secret_names(by:, reload: false)
      return props[:secret_names] if props[:secret_names] && !reload

      get_checked(user: by)
      return props[:secret_names]
    end

    def get_secrets(by:, reload: false)
      secret_names = get_secret_names(by: by, reload: reload)
      Secret.list(user: by, project: project).select do |s|
        secret_names.include? s.name
      end
    end

    # cache some usualy immutable properties for later fast use; do not cache
    #   things that can change at any time
    def update_from_api_object(service_acc_hash)
      m = service_acc_hash["metadata"]
      s = service_acc_hash["secrets"]

      if shortname != m["name"]
        raise "looks like a hash from another account: #{name} vs #{m["name"]}"
      end
      if m['namespace'] != project.name
        raise "looks like account from another project: #{project.name} vs #{m['namespace']}"
      end

      props[:created] = m["creationTimestamp"]
      props[:uid] = m['uid']

      props[:secret_names] = s.map {|s| s['name']} # lets cache as useful

      return self
    end

    def clean_up
      # do nothing
    end

    def clean_up_on_load
      # do nothing
    end

    ############### deal with comparison ###############
    def ==(sa)
      sa.kind_of?(self.class) && name == sa.name && project == sa.project
    end
    alias eql? ==

    def hash
      :service_account.hash ^ name.hash ^ project.hash
    end
  end
end
