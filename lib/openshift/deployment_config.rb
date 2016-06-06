require 'openshift/project_resource'

module CucuShift
  # represents an OpenShift DeploymentConfig (dc for short) used for scaling pods
  class DeploymentConfig < ProjectResource
    RESOURCE = "deploymentconfigs"
    STATUSES = [:waiting, :running, :succeeded, :failed, :complete]

    # cache some usualy immutable properties for later fast use; do not cache
    #   things that can change at any time like status and spec
    def update_from_api_object(dc_hash)
      m = dc_hash["metadata"]
      s = dc_hash["spec"]
      props[:uid] = m["uid"]
      props[:labels] = m["labels"]
      props[:created] = m["creationTimestamp"] # already [Time]
      props[:spec] = s

      return self # mainly to help ::from_api_object
    end

    # @param from_status [Symbol] the status we currently see
    # @param to_status [Array, Symbol] the status(es) we check whether current
    #   status can change to
    # @return [Boolean] true if it is possible to transition between the
    #   specified statuses (same -> same should return true)
    def status_reachable?(from_status, to_status)
      [to_status].flatten.include?(from_status) ||
        ![:failed, :succeeded].include?(from_status)
    end

    # @param status [Symbol, Array<Symbol>] the expected statuses as a symbol
    # @return [Boolean] if pod status is what's expected
    # @note TODO: can we just remove method and use [Resource#status?]
    def status?(user:, status:, quiet: false, cached: false)
      statuses = {
        waiting: "Waiting",
        running: "Running",
        succeeded: "Succeeded",
        failed: "Failed",
        complete: "Complete",
      }
      res = describe(user, quiet: quiet)
      if res[:success]
        res[:success] = res[:parsed][:overall_status] == statuses[status]
      end
      return res
    end

    # @return [CucuShift::ResultHash] with :success depending on status['replicas'] == spec['replicas']
    def ready?(user, quiet: false)
      res = describe(user, quiet: quiet)

      if res[:success]
        # return success if the pod is running
        res[:success] =  res[:parsed][:pods_status][:running].to_i == 1
      end
      return res
    end
  end
end
