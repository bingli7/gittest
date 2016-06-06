Feature: jenkins.feature
  # @author xiuwang@redhat.com
  # @case_id 498668
  @admin
  @destructive
  Scenario: Could change password for jenkins server--jenkins-1-rhel7
    Given I have a project
    And I have a NFS service in the project
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/db-templates/auto-nfs-pv.json" where:
      | ["spec"]["nfs"]["server"] | <%= service("nfs-service").ip %> |
    When I run the :new_app client command with:
      | template | jenkins-persistent |
    Given I wait for the "jenkins" service to become ready
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl | -usS | admin:password | <%= service.url %> |
    Then the step should succeed
    """
    And the output should contain:
      | Dashboard [Jenkins] |
    When I run the :env client command with:
      | resource | dc/jenkins  |
      | e        | JENKINS_PASSWORD=redhat |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=jenkins |
      | deployment=jenkins-2 |
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl | -usS | admin:redhat | <%= service.url %> |
    Then the step should succeed
    """
    And the output should contain:
      | Dashboard [Jenkins] |
