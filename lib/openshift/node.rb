require 'yaml'
require 'common'

module CucuShift
  # @note this class represents OpenShift environment Node API pbject and this
  #   is different from a CucuShift::Host. Underlying a Node, there always is a
  #   Host but not all Hosts are Nodes. Not sure if we can always have a
  #   mapping between Nodes and Hosts. Depends on access we have to the env
  #   under testing and proper configuration.
  class Node
    include Common::Helper
    include Common::UserObjectHelper

    attr_reader :name, :env, :props

    def initialize (name:, env:, props: {})
      if name.nil? || env.nil?
        raise "node need name and environment to be identified"
      end

      @name = name.freeze
      @env = env
      @props = props
    end

    # list all nodes
    # @param user [CucuShift::User]
    # @return [Array<Node>]
    # @note raises error on issues
    def self.list(user:)
      res = user.cli_exec(:get, resource: "nodes", output: "yaml")
      if res[:success]
        list = YAML.load(res[:response])["items"]
        return list.map { |node_hash|
          self.from_api_object(user.env, node_hash)
        }
      else
        raise "error getting nodes for user: '#{user}'"
      end
    end

    # creates new node from an OpenShift API Node object
    def self.from_api_object(env, node_hash)
      self.new(name: node_hash["metadata"]["name"], env: env).update_from_api_object(node_hash)
    end

    def update_from_api_object(node_hash)
      h = node_hash["metadata"]
      props[:uid] = h["uid"]
      props[:labels] = h["labels"]
      return self
    end

    # @note assuming admin here should be safe as working with nodes
    #   usually means that we work with admin
    def labels(user: :admin)
      return props[:labels] if props[:labels]
      reload(user: user)
      props[:labels]
    end

    # @return [CucuShift:Host] underlying this node
    # @note may raise depending on proper OPENSHIFT_ENV_<NAME>_HOSTS
    def host
      env.hosts.find { |h| h.hostname == self.name } ||
        raise("no host mapping for #{self.name}")
    end

    def get(user:)
      res = cli_exec(as: user, key: :get,
                resource_name: name,
                resource: "node",
                output: "yaml")

      if res[:success]
        res[:parsed] = YAML.load(res[:response])
        update_from_api_object(res[:parsed])
      end

      return res
    end
    alias reload get

    ############### take care of object comparison ###############
    def ==(n)
      n.kind_of?(self.class) && name == n.name && env == n.env
    end
    alias eql? ==

    def hash
      :node.hash ^ name.hash ^ env.hash
    end
  end
end
