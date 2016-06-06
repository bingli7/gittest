require 'yaml'

require_relative 'resource'

module CucuShift
  # @note represents a Resource / OpenShift API Object
  class ClusterResource < Resource

    attr_reader :env

    def initialize(name:, env:, props: {})

      if name.nil? || env.nil?
        raise "ClusterResource needs name and environment to be identified"
      end

      @name = name.freeze
      @env = env
      @props = props
    end

    # creates a new OpenShift Cluster Resource from spec
    # @param by [CucuShift::User, CucuShift::ClusterAdmin] the user to create
    #   Resource as
    # @param spec [String, Hash] the Hash representaion of the API object to
    #   be created or a String path of a JSON/YAML file
    # @return [CucuShift::ResultHash]
    def self.create(by:, spec:, **opts)
      if spec.kind_of? String
        # assume a file path (TODO: be more intelligent)
        spec = YAML.load_file(spec)
      end
      name = spec["metadata"]["name"] || raise("no name specified for resource")
      create_opts = { f: '-', _stdin: spec.to_json, **opts }
      init_opts = {name: name, env: by.env}

      res = by.cli_exec(:create, **create_opts)
      res[:resource] = self.new(**init_opts)

      return res
    end

    # creates new resource from an OpenShift API Project object
    # @note requires subclass to define `#update_from_api_object`
    def self.from_api_object(env, resource_hash)
      unless Environment === env
        raise "env parameter must be an Environment but is: #{env.inspect}"
      end
      self.new(env: env, name: resource_hash["metadata"]["name"]).
                                update_from_api_object(resource_hash)
    end

    # @param labels [String, Array<String,String>] labels to filter on, read
    #   [CucuShift::Common::BaseHelper#selector_to_label_arr] carefully
    # @param count [Integer] minimum number of resources to wait for
    def self.wait_for_labeled(*labels, count: 1, user:, seconds:)
      wait_for_matching(user: user, seconds: seconds,
                        get_opts: {l: selector_to_label_arr(*labels)},
                        count: count) do |item, item_hash|
                          !block_given? || yield(item, item_hash)
      end
    end

    # @param count [Integer] minimum number of items to wait for
    # @yield block that selects items by returning true; see [#get_matching]
    # @return [CucuShift::ResultHash] with :matching key being array of matched
    #   resource items;
    def self.wait_for_matching(count: 1, user:, seconds:, get_opts: [])
      res = {}

      quiet = get_opts.find {|k,v| k == :_quiet}
      if quiet
        # TODO: we may think about `:false` string value if passed by a step
        quiet = quiet[1]
      else
        quiet = true
        get_opts = get_opts.to_a << [:_quiet, true]
      end

      stats = {}
      wait_for(seconds, interval: 3, stats: stats) {
        get_matching(user: user, result: res, get_opts: get_opts) { |resource, resource_hash|
          yield resource, resource_hash
        }
        res[:success] = res[:matching].size >= count
      }

      if quiet
        # user didn't see any output, lets print used command
        user.env.logger.info res[:command]
      end
      user.env.logger.info "#{stats[:iterations]} iterations for #{stats[:full_seconds]} sec, returned #{res[:items].size} #{self::RESOURCE}, #{res[:matching].size} matching"

      return res
    end

    # list resources by a user
    # @param user [CucuShift::User] the user we list resources as
    # @param result [ResultHash] can be used to get full result hash from op
    # @param get_opts [Hash, Array] other options to pass down to oc get
    # @return [Array<Resouece>]
    # @note raises error on issues
    def self.get_matching(user:, result: {}, get_opts: [])
      # construct options
      opts = [ [:resource, self::RESOURCE],
               [:output, "yaml"]
      ]
      get_opts.each { |k,v|
        if [:resource, :output, :o, :resource_name,
            :w, :watch, :watch_only, :n, :namespace].include?(k)
          raise "incompatible option #{k} provided in get_opts"
        else
          opts << [k, v]
        end
      }

      res = result
      res.merge! user.cli_exec(:get, opts)
      if res[:success]
        res[:parsed] = YAML.load(res[:response])
        res[:items] = res[:parsed]["items"].map { |item_hash|
          self.from_api_object(user.env, item_hash)
        }
      else
        user.env.logger.error(res[:response])
        raise "error getting #{self::RESOURCE} by user: '#{user}'"
      end

      res[:matching] = []
      res[:items].zip(res[:parsed]["items"]) { |i, i_hash|
        res[:matching] << i if !block_given? || yield(i, i_hash)
      }

      return res[:matching]
    end
    class << self
      alias list get_matching
    end

    ############### take care of object comparison ###############
    def ==(p)
      p.kind_of?(self.class) && name == p.name && env == p.env
    end
    alias eql? ==

    def hash
      self.class.name.hash ^ name.hash ^ env.hash
    end
  end
end
