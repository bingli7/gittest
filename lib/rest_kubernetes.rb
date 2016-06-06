require 'rest_helper'

module CucuShift
  module Rest
    module Kubernetes
      extend Helper

      def self.populate(path, base_opts, opts)
        populate_common("/api/<api_version>", path, base_opts, opts)
      end

      class << self
        alias perform perform_common
      end

      def self.access_heapster(base_opts, opts)
        populate("/proxy/namespaces/<project_name>/services/https:heapster:/api/v1/model/metrics", base_opts, opts)
        base_opts[:headers].delete("Accept") unless opts[:keep_accept]
        return perform(**base_opts, method: "GET")
      end

      def self.delete_subresources_api(base_opts, opts)
        populate("/namespaces/<project_name>/<resource_type>/<resource_name>/status", base_opts, opts)
        return perform(**base_opts, method: "DELETE")
      end

    end
  end
end
