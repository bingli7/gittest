require 'openshift/project_resource'

module CucuShift
  # represents an OpenShift ReplicationController (rc for short) used for scaling pods
  class ReplicationController < ProjectResource
    RESOURCE = "replicationcontrollers"

    # cache some usualy immutable properties for later fast use; do not cache
    #   things that can change at any time like status and spec
    def update_from_api_object(rc_hash)
      m = rc_hash["metadata"]
      s = rc_hash["spec"]
      props[:uid] = m["uid"]
      props[:labels] = m["labels"]
      props[:annotations] = m["annotations"] # may change, use with care
      props[:created] = m["creationTimestamp"] # already [Time]
      props[:spec] = s
      props[:status] = rc_hash["status"] # may change, use with care

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
    # def status?(user:, status:, quiet: false, cached: false)
    #   statuses = {
    #     waiting: "Waiting",
    #     running: "Running",
    #     succeeded: "Succeeded",
    #     failed: "Failed",
    #     complete: "Complete",
    #   }
    #   res = describe(user, quiet: quiet)
    #   if res[:success]
    #     pods_status = res[:parsed][:pods_status]
    #     res[:success] = (pods_status[status].to_i != 0)
    #   end
    #   return res
    # end

    # @return [CucuShift::ResultHash] with :success depending on
    #   status['replicas'] == spec['replicas']
    # @note we also need to check that the spec.replicas is > 0
    def ready?(user:, quiet: false, cached: false)
      if cached && props[:status] && props[:annotations] && props[:spec]
        cache = {
          "status" => props[:status],
          "spec" => props[:spec],
          "metadata" => {"annotations" => props[:annotations]}
        }

        res = {
          success: true,
          instruction: "get rc #{name} cached ready status",
          response: cache.to_yaml,
          parsed: cache
        }
        current_replicas = props[:status]["replicas"]
        expected_replicas = props[:spec]["replicas"]
        deployment_phase = props[:annotations]["openshift.io/deployment.phase"]
      else
        res = get(user: user, quiet: quiet)
        return res unless res[:success]
        current_replicas = res[:parsed]["status"]["replicas"]
        expected_replicas = res[:parsed]["spec"]["replicas"]
        deployment_phase = res[:parsed]['metadata']['annotations']["openshift.io/deployment.phase"]
      end
      res[:success] = expected_replicas.to_i > 0 &&
                      current_replicas == expected_replicas &&
                      deployment_phase == 'Complete'
      return res
    end

    # @return [CucuShift::ResultHash]
    def replica_count_match?(user:, state:, replica_count:, quiet: false)
      res = describe(user, quiet: quiet)
      if res[:success]
        res[:success] = res[:parsed][:pods_status][state].to_i == replica_count
      end
      return res
    end

    # @return [CucuShift::ResultHash] with :success true if we've eventually
    #   get the number of reclicas 'running' to match the desired number
    def wait_till_replica_count_match(user:, state:, seconds:, replica_count:)
      res = nil
      iterations = 0
      start_time = monotonic_seconds

      success = wait_for(seconds) {
        res = replica_count_match?(user: user, state: state, replica_count: replica_count, quiet: true)

        logger.info res[:command] if iterations == 0
        iterations = iterations + 1

        res[:success]
      }

      duration = monotonic_seconds - start_time
      logger.info "After #{iterations} iterations and #{duration.to_i} " <<
        "seconds:\n#{res[:response]}"

      return res
    end
  end
end
