require 'yaml'

require 'common'

module CucuShift
  # @note represents an OpenShift route to a service
  #   https://docs.openshift.com/enterprise/3.0/architecture/core_concepts/routes.html
  class Route
    include Common::Helper
    include Common::UserObjectHelper

    attr_reader :props, :name, :service

    # @param name [String] name of route
    # @param service [CucuShift::Service] the service exposed via this route
    # @param props [Hash] additional properties of the route
    def initialize(name: nil, service:, props: {})
      @name = name || service.name
      @service = service
      @props = props
    end

    def env
      service.env
    end

    # @param by [CucuShift::User] the user to delete route with
    def delete(by:)
      cli_exec(as: by, key: :delete,
               object_type: :route,
               object_name_or_id: name,
               namespace: service.project.name)
    end

    # @param by [CucuShift::User] the user to create route with
    def create(by:)
      res = cli_exec(as: by, key: :expose, output: :yaml,
                          resource: :service,
                          resource_name: name,
                          namespace: service.project.name)

      if res[:success]
        res[:parsed] = YAML.load(res[:response])
      end

      return res
    end

    # load route props from a Route OpenShift API object
    #   apiVersion: v1
    #   kind: Route
    #   metadata:
    #     annotations:
    #       openshift.io/host.generated: "true"
    #     creationTimestamp: 2015-07-27T15:24:58Z
    #     name: myapp
    #     namespace: xaxa
    #     resourceVersion: "52293"
    #     selfLink: /osapi/v1beta3/namespaces/xaxa/routes/myapp
    #     uid: a454f9db-3473-11e5-a56e-fa163eee310a
    #   spec:
    #     host: myapp.xaxa.cloudapps.example.com
    #     to:
    #       kind: Service
    #       name: myapp
    #   status: {}
    def load(hash)
      props[:dns] = hash["spec"]["host"]
    end

    # get Route API object from OpenShift API and load any data
    def get(by:)
      res = cli_exec(as: by, key: :get, output: :yaml,
                     namespace: service.project.name,
                     resource: :route,
                     resource_name: name)

      if res[:success]
        res[:parsed] = YAML.load(res[:response])
        load(res[:parsed])
      end

      return res
    end

    def http_get(by:, proto: "http", port: nil, quiet: false)
      portstr = port ? ":#{port}" : ""
      CucuShift::Http.get(url: proto + "://" + dns(by: by) + portstr,
                          quiet: quiet)
    end

    def wait_http_accessible(by:, timeout: nil, proto: "http", port: nil)
      # TODO: are there non-http routes? we may try to auto-sense the proto
      res = nil
      timeout ||= 15*60

      iterations = 0
      start_time = monotonic_seconds

      wait_for(timeout) {
        res = http_get(by: by, proto: proto, port: port, quiet: true)

        logger.info res[:instruction] if iterations == 0
        iterations = iterations + 1

        if SocketError === res[:error] &&
            res[:error].to_s.include?('getaddrinfo')
          # unlikely to ever succeed when we can't resolve domain name
          break
        end
        res[:success]
      }

      duration = monotonic_seconds - start_time
      logger.info "After #{iterations} iterations and #{duration.to_i} " <<
        " seconds:\n#{res[:response]}"

      return res
    end

    def dns(by:)
      if props[:dns]
        return props[:dns]
      else
        res = get(by: by)
        if res[:success]
          return props[:dns]
        else
          logger.error(res[:response])
          raise "could not obtain route DNS name, see log"
        end
      end
    end

    def ==(r)
      r.kind_of?(self.class) && name == r.name && service == r.service
    end
    alias eql? ==

    def hash
      :route.hash ^ name.hash ^ service.hash
    end
  end
end
