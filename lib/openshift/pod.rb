require 'openshift/project_resource'

module CucuShift
  # represents an OpenShift pod
  class Pod < ProjectResource
    RESOURCE = "pods"
    # https://github.com/kubernetes/kubernetes/blob/master/pkg/api/types.go
    STATUSES = [:pending, :running, :succeeded, :failed, :unknown]
    # statuses that indicate pod running or completed successfully
    SUCCESS_STATUSES = [:running, :succeeded, :missing]

    # cache some usualy immutable properties for later fast use; do not cache
    #   things that ca nchange at any time like status and spec
    def update_from_api_object(pod_hash)
      m = pod_hash["metadata"]
      props[:uid] = m["uid"]
      props[:generateName] = m["generateName"]
      props[:labels] = m["labels"]
      props[:created] = m["creationTimestamp"] # already [Time]
      props[:annotations] = m["annotations"]
      props[:deployment_config_version] = m["annotations"]["openshift.io/deployment-config.latest-version"]
      props[:deployment_config_name] = m["annotations"]["openshift.io/deployment-config.name"]
      props[:deployment_name] = m["annotations"]["openshift.io/deployment.name"]

      # for builder pods
      props[:build_name] = m["annotations"]["openshift.io/build.name"]

      # for deployment pods
      # ???

      spec = pod_hash["spec"] # this is runtime, lets not cache
      props[:node_hostname] = spec["host"]
      props[:node_name] = spec["nodeName"]
      props[:fs_group] = spec["securityContext"]["fsGroup"]

      s = pod_hash["status"]
      props[:ip] = s["podIP"]
      # status should be retrieved on demand but we cache it for the brave
      props[:status] = s


      return self # mainly to help ::from_api_object
    end

    # @return [CucuShift::ResultHash] with :success depending on status=True
    #   with type=Ready
    def ready?(user:, quiet: false, cached: false)
      if cached && props[:status]
        res = { instruction: "get cached pod #{name} readiness",
                response: {"status" => props[:status]}.to_yaml,
                success: true,
                exitstatus: 0,
                parsed: {"status" => props[:status]}
        }
      else
        res = get(user: user, quiet: quiet)
      end

      if res[:success]
        res[:success] =
          res[:parsed]["status"] &&
          res[:parsed]["status"]["conditions"] &&
          res[:parsed]["status"]["conditions"].any? { |c|
            c["type"] == "Ready" && c["status"] == "True"
          }
      end

      return res
    end

    # @note call without parameters only when props are loaded
    def ip(user: nil)
      get_checked(user: user) if !props[:ip]

      return props[:ip]
    end

    # @note call without parameters only when props are loaded
    def fs_group(user: nil)
      get_checked(user: user) if !props[:fs_group]

      return props[:fs_group].to_s
    end

    # @note call without parameters only when props are loaded
    def node_hostname(user: nil)
      get_checked(user: user) if !props[:node_hostname]

      return props[:node_hostname]
    end

    # @note call without parameters only when props are loaded
    def node_name(user: nil)
      get_checked(user: user) if !props[:node_name]

      return props[:node_name]
    end

    # this useful if you wait for a pod to die
    def wait_till_not_ready(user, seconds)
      res = nil
      iterations = 0
      start_time = monotonic_seconds

      success = wait_for(seconds) {
        res = ready?(user: user, quiet: true)

        logger.info res[:command] if iterations == 0
        iterations = iterations + 1

        ! res[:success]
      }

      duration = monotonic_seconds - start_time
      logger.info "After #{iterations} iterations and #{duration.to_i} " <<
        "seconds:\n#{res[:response]}"

      res[:success] = success
      return res
    end

    # @param from_status [Symbol] the status we currently see
    # @param to_status [Array, Symbol] the status(es) we check whether current
    #   status can change to
    # @return [Boolean] true if it is possible to transition between the
    #   specified statuses (same -> should be true)
    def status_reachable?(from_status, to_status)
      [to_status].flatten.include?(from_status) ||
        ![:failed, :unknown].include?(from_status)
    end

    # executes command on pod
    def exec(command, *args, as:)
      #opts = []
      #opts << [:pod, name]
      #opts << [:cmd_opts_end, true]
      #opts << [:exec_command, command]
      #args.each {|a| opts << [:exec_command_arg, a]}
      #
      #env.cli_executor.exec(as, :exec, opts)

      cli_exec(as: as, key: :exec, pod: name, n: project.name,
               oc_opts_end: true,
               exec_command: command,
               exec_command_arg: args)
    end
  end
end
