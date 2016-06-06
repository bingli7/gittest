Feature: Storage of Ceph plugin testing
	
  # @author wehe@redhat.com
  # @case_id 522141
  @admin @destructive
  Scenario: Ceph persistant volume with invalid monitors
    Given I have a project

    #Create a invlid pv with rbd of wrong monitors
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/rbd/rbd-secret.yaml |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/rbd/pv-retain.json"
    And I replace content in "pv-retain.json":
      |/\d{3}/|000|
    When admin creates a PV from "pv-retain.json" where:
      | ["metadata"]["name"] | rbd-<%= project.name %> |
    Then the step should succeed

    #Create ceph pvc
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/rbd/pvc-rwo.json |
    Then the step should succeed
    And the PV becomes :bound

    #Create the scc for the rbd pod
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/scc_privileged.yaml"
    And I replace lines in "scc_privileged.yaml":
      |system:serviceaccounts:default|system:serviceaccounts:<%= project.name %>|
      |scc-pri|<%= rand_str(6, :dns) %>|
    And the following scc policy is created: scc_privileged.yaml

    #Creat the pod
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/rbd/pod.json |
    Then the step should succeed
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pods |
      | name | rbdpd |
    Then the output should contain:
      | FailedMount |
      | rbd: map failed |
    """

