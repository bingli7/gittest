Feature: Persistent Volume reclaim policy tests
  # @author jhou@redhat.com
  # @case_id 488979
  @admin
  Scenario: Recycle reclaim policy for persistent volumes
    # Preparations
    Given I have a project
    And I have a NFS service in the project
    # Creating PV and PVC
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv.json" where:
      | ["spec"]["nfs"]["server"] | <%= service("nfs-service").ip %> |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pvc.json |
    Then the step should succeed
    Given the PV becomes :bound
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/web-pod.json |
    And the pod named "nfs" becomes ready
    When I run the :get client command with:
      | resource | pod/nfs |
    Then the output should contain:
      | Running |
    Given I run the :delete client command with:
      | object_type       | pod |
      | object_name_or_id | nfs |
    And I run the :delete client command with:
      | object_type       | pvc  |
      | object_name_or_id | nfsc |
    And the PV becomes :available
    When I run the :get admin command with:
      | resource | pv/<%= pv.name %> |
    Then the output should contain:
      | Available |
