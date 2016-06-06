require 'openshift/project_resource'

module CucuShift
  # represents an OpenShift PersistentVolumeClaim (pvc for short)
  class PersistentVolumeClaim < ProjectResource
    STATUSES = [:bound, :failed, :pending]
    RESOURCE = "persistentvolumeclaims"

    # cache some usualy immutable properties for later fast use; do not cache
    #   things that can change at any time like status and spec
    def update_from_api_object(dc_hash)
      m = dc_hash["metadata"]
      s = dc_hash["spec"]
      props[:labels] = m["labels"]
      props[:created] = m["creationTimestamp"] # already [Time]
      props[:spec] = s
      props[:status] = dc_hash["status"] # for brave and stupid people

      return self # mainly to help ::from_api_object
    end

    # @return [CucuShift::ResultHash] with :success if status is Bound
    def ready?(user, quiet: false, cached: false)
      status?(user: user, status: :bound, quiet: quiet, cached: cached)
    end
  end
end
