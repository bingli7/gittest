require 'json'
require 'yaml'

require 'openshift/resource'

module CucuShift
  # @note represents an OpenShift namespaced Resource (part of a Project)
  class ProjectResource < Resource
    attr_reader :project

    # RESOURCE = "define me"

    # @param name [String] name of the resource
    # @param project [CucuShift::Project] the project we belong to
    # @param props [Hash] additional properties of the resource
    def initialize(name:, project:, props: {})
      @name = name
      @project = project
      @props = props
    end

    def env
      project.env
    end

    # @note requires sub-class to define `#parse_oc_describe` method
    def describe(user, quiet: false)
      resource_type = self.class::RESOURCE
      resource_name = name
      cli_opts = {
        as: user, key: :describe, n: project.name,
        name: resource_name,
        resource: resource_type,
        _quiet: quiet
      }
      cli_opts[:_quiet] = quiet if quiet

      res = cli_exec(**cli_opts)
      res[:parsed] = self.parse_oc_describe(res[:response]) if res[:success]
      return res
    end

    # creates a new OpenShift Project Resource via API
    # @param by [CucuShift::User, CucuShift::ClusterAdmin] the user to create
    #   ProjectResource as
    # @param project [CucuShift::Project] the namespace for the new resource
    # @param spec [String, Hash] the Hash object to create project resource or
    #   a String path of a JSON/YAML file
    # @return [CucuShift::ResultHash]
    def self.create(by:, project:, spec:, **opts)
      if spec.kind_of? String
        # assume a file path (TODO: be more intelligent)
        case spec
        when %r{https?://}
          spec = YAML.load(Http.get(url: spec, raise_on_error: true)[:response])
        else
          spec = YAML.load_file(spec)
        end
      end
      name = spec["metadata"]["name"]
      # TODO: verify resource type!

      res = by.cli_exec(:create, n: project.name, f: '-',
                        _stdin: spec.to_json, **opts)
      res[:resource] = self.new(name: name, project: project)

      return res
    end

    # creates new ProjectResource from an OpenShift API object hash
    def self.from_api_object(project, resource_hash)
      self.new(project: project, name: resource_hash["metadata"]["name"]).
                                update_from_api_object(resource_hash)
    end

    def delete(by:)
      cli_exec(as: by, key: :delete, object_type: self.class::RESOURCE,
               object_name_or_id: name, namespace: project.name)
    end

    # @param labels [String, Array<String,String>] labels to filter on, read
    #   [CucuShift::Common::BaseHelper#selector_to_label_arr] carefully
    # @param count [Integer] minimum number of resources to wait for
    def self.wait_for_labeled(*labels, count: 1, user:, project:, seconds:)
      wait_for_matching(user: user, project: project, seconds: seconds,
                        get_opts: {l: selector_to_label_arr(*labels)},
                        count: count)  do |item, item_hash|
                          !block_given? || yield(item, item_hash)
      end
    end

    # @param count [Integer] minimum number of items to wait for
    # @yield block that selects items by returning true; see [#get_matching]
    # @return [CucuShift::ResultHash] with :matching key being array of matched
    #   resource items;
    def self.wait_for_matching(count: 1, user:, project:, seconds:,
                                                                  get_opts: [])
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
        get_matching(user: user, project: project, result: res, get_opts: get_opts) { |resource, resource_hash|
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

    def self.get_labeled(*labels, user:, project:, result: {})
      get_matching(user: user, project: project, result: result,
                   get_opts: {l: selector_to_label_arr(*labels)}) do |r, r_hash|
        !block_given? || yield(r, r_hash)
      end
    end

    # @yield block that selects resource items by returning true; block receives
    #   |resource, resource_hash| as parameters where resource is a reloaded
    #   [Resource] sub-type, e.g. [Pod], [Build], etc.
    # @return [Array<ProjectResource>] with :matching key being array of matched
    #   resources
    def self.get_matching(user:, project:, result: {}, get_opts: [])
      # construct options
      opts = [ [:resource, self::RESOURCE],
               [:output, "yaml"],
               [:n, project.name]
      ]
      get_opts.each { |k,v|
        if [:resource, :output, :o, :n, :namespace, :resource_name,
            :w, :watch, :watch_only].include?(k)
          raise "incompatible option #{k} provided in get_opts"
        else
          opts << [k, v]
        end
      }

      res = result
      res.merge! user.cli_exec(:get, opts)

      if res[:success]
        res[:parsed] = YAML.load(res[:response])
        res[:items] = res[:parsed]["items"].map { |i|
          self.from_api_object(project, i)
        }
      else
        user.env.logger.error(res[:response])
        raise "cannot get #{self::RESOURCE} for project #{project.name}"
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
      p.kind_of?(self.class) && name == p.name && project == p.project
    end
    alias eql? ==

    def hash
      self.class.name.hash ^ name.hash ^ project.hash
    end
  end
end
