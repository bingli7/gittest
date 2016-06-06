Feature: Storage of GlusterFS plugin testing
	
  # @author wehe@redhat.com
  # @case_id 522140
  @admin @destructive
  Scenario: Gluster storage testing with Invalid gluster endpoint
    Given I have a project

    #Create a invlid endpoint
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/gluster/endpoints.json"
    And I replace content in "endpoints.json":
      |/\d{2}/|11|
    And I run the :create client command with:
      | f | endpoints.json |
    Then the step should succeed
    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/gluster/pv-retain-rwo.json" where:
      | ["metadata"]["name"] | gluster-<%= project.name %> |
    Then the step should succeed

    #Create gluster pvc
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/gluster/claim-rwo.json |
    Then the step should succeed
    And the PV becomes :bound

    #Creat the pod
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/gluster/pod.json |
    Then the step should succeed
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pods |
      | name | gluster |
    Then the output should contain:
      | FailedMount |
      | glusterfs: mount failed |
    """

