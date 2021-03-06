require 'openshift/project_resource'

module CucuShift
  # represents an OpenShift build
  class Build < ProjectResource
    RESOURCE = "builds"
    # https://github.com/openshift/origin/blob/master/pkg/build/api/v1/types.go
    #  (look for `const` definition)
    STATUSES = [:complete, :running, :pending, :new, :failed, :error, :cancelled]
    TERMINAL_STATUSES = [:complete, :failed, :cancelled, :error]

    # creates new Build object from an OpenShift API Pod object
    def self.from_api_object(project, build_hash)
      self.new(project: project, name: build_hash["metadata"]["name"]).
                                update_from_api_object(build_hash)
    end

    # cache some usualy immutable properties for later fast use; do not cache
    #   things that can change at any time like status and spec
    def update_from_api_object(build_hash)
      m = build_hash["metadata"]
      s = build_hash["spec"]

      if name != m["name"]
        raise "looks like a hash from another account: #{name} vs #{m["name"]}"
      end
      if m['namespace'] != project.name
        raise "looks like account from another project: #{project.name} vs #{m['namespace']}"
      end

      props[:uid] = m["uid"]
      props[:labels] = m["labels"]
      props[:created] = m["creationTimestamp"] # already [Time]

      props[:spec] = s

      return self # mainly to help ::from_api_object
    end

    # @return [CucuShift::ResultHash] :success if build completes regardless of
    #   completion status
    def finished?(user:, quiet: false)
      status?(user: user, status: TERMINAL_STATUSES, quiet: quiet)
    end

    # @return [CucuShift::ResultHash] with :success depending on status
    def completed?(user:)
      status?(user: user, status: :complete)
    end

    # @return [CucuShift::ResultHash] with :success depending on status
    def failed?(user:)
      status?(user: user, status: :failed)
    end

    # @return [CucuShift::ResultHash] with :success depending on status
    def running?(user:)
      status?(user: user, status: :running)
    end

    # @return [CucuShift::ResultHash] with :success true if we've eventually got
    #   the build finished regardless of status, false if build never started or
    #   still running; the result hash is from last executed get call
    def wait_till_finished(user, seconds)
      res = nil
      iterations = 0
      start_time = monotonic_seconds

      wait_for(seconds) {
        res = finished?(user: user, quiet: true)

        logger.info res[:command] if iterations == 0
        iterations = iterations + 1

        res[:success]
      }

      duration = monotonic_seconds - start_time
      logger.info "After #{iterations} iterations and #{duration.to_i} " <<
        "seconds:\n#{res[:response]}"

      return res
    end

    # @return [CucuShift::ResultHash] with :success true if we've eventually got
    #   the build completed; the result hash is from last executed get call
    def wait_till_completed(user, seconds)
      wait_till_status(:complete, user, seconds)
    end

    # @return [CucuShift::ResultHash] with :success true if we've eventually got
    #   the build failed; the result hash is from last executed get call
    def wait_till_failed(user, seconds)
      wait_till_status(:failed, user, seconds)
    end

    def wait_till_cancelled(user, seconds)
      wait_till_status(:cancelled, user, seconds)
    end

    def wait_till_running(user, seconds)
      wait_till_status(:running, user, seconds)
    end

    def wait_till_pending(user, seconds)
      wait_till_status(:pending, user, seconds)
    end

    # @param from_status [Symbol] the status we currently see
    # @param to_status [Array, Symbol] the status(es) we check whether current
    #   status can change to
    # @return [Boolean] true if it is possible to transition between the
    #   specified statuses (same -> should be true)
    def status_reachable?(from_status, to_status)
      if [to_status].flatten.include?(from_status)
        return true
      elsif TERMINAL_STATUSES.include?(from_status)
        if from_status == :failed &&
            [ to_status ].flatten.include?(:cancelled)
          return true
        end
        return false
      end
      return true
    end
  end
end
