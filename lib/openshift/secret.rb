require "base64"
require 'tempfile'

require 'common'

module CucuShift
  # represents an OpenShift Secret
  class Secret
    include Common::Helper
    include Common::UserObjectHelper

    attr_reader :props, :name, :project

    # @param name [String] name of secret
    # @param project [CucuShift::Project] the project secret belongs to
    # @param props [Hash] additional properties of the secret
    def initialize(name:, project:, props: {})
      @name = name
      @project = project
      @props = props
    end

    # @param by [User, ClusterAdmin, :admin] the user to create secret with
    # @param hash [Hash] API object hash to define new secret (or specify file)
    # @param file [String] file containing API secret object
    def create(by:, hash: nil, file: nil)
      tmpfile = nil
      if file
        # do nothing
      elsif hash
        tmpfile = Tempfile.new(['secret','.json'])
        tmpfile.write(hash.to_json)
        tmpfile.close
        file = tmpfile.path
      else
        raise "hash or file needed to create a secret"
      end

      return cli_exec(as: by, key: :create, f: file, n: project.name)
    ensure
      if tmpfile
        tmpfile.close
        tmpfile.unlink
      end
    end

    # creates new secret from an OpenShift API Secret object
    def self.from_api_object(project, secret_hash)
      self.new(project: project, name: secret_hash["metadata"]["name"]).
                                update_from_api_object(secret_hash)
    end

    # cache some usualy immutable properties for later fast use; do not cache
    #   things that can change
    def update_from_api_object(hash)
      m = hash["metadata"]
      props[:uid] = m["uid"]
      props[:labels] = m["labels"]
      props[:created] = m["creationTimestamp"] # already [Time]
      props[:annotations] = m["annotations"]

      props[:type] = hash["type"]
      props[:data] = hash["data"]

      return self # mainly to help ::from_api_object
    end

    # @param user [CucuShift::User] the user to run cli commands with if needed
    def get(user:)
      res = cli_exec(as: user, key: :get, n: project.name,
                resource_name: name,
                resource: "secret",
                output: "yaml")

      if res[:success]
        res[:parsed] = YAML.load(res[:response])
        update_from_api_object(res[:parsed])
      end

      return res
    end
    alias reload get

    # @param user [CucuShift::User] the user to run cli commands with if needed
    def type(user:)
      return props[:type] if props[:type]

      reload(by: user)
      return props[:type]
    end

    # @param user [CucuShift::User] the user to run cli commands with if needed
    def bearer_token?(user:)
      type(user: user).include?('service-account-token') &&
        props[:data]["token"]
    end

    # @param user [CucuShift::User] the user to run cli commands with if needed
    # @return [String] bearer token
    def token(user:)
      if bearer_token?(user: user)
        return Base64.decode64(props[:data]["token"])
      else
        raise "secret #{name} does not contain a token"
      end
    end

    # list secrets for a project
    # @param user [User, ClusterAdmin] the user who's running the commands
    # @param project [Project] the project to list secrets in
    # @return [Array<Secret>]
    # @note raises error on issues
    def self.list(user:, project:)
      res = user.cli_exec(:get, resource: "secret",
                          output: "yaml", n: project.name)
      if res[:success]
        list = YAML.load(res[:response])["items"]
        return list.map { |secret_hash|
          self.from_api_object(project, secret_hash)
        }
      else
        logger.error(res[:response])
        raise "error getting projects for user: '#{user}'"
      end
    end

    # creates a Secret object from API hash
    # @param user [User, ClusterAdmin] the user who's running the commands
    # @param project [Project] the project to list secrets in
    # @return [Secret]
    # @note raises error on issues
    def self.from_api_object(project, secret_hash)
      self.new(name: secret_hash["metadata"]["name"], project: project).
               update_from_api_object(secret_hash)
    end

    def env
      project.env
    end

    def ==(s)
      s.kind_of?(self.class) && name == s.name && project == s.project
    end
    alias eql? ==

    def hash
      :secret.hash ^ name.hash ^ project.hash
    end
  end
end
