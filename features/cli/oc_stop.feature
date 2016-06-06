Feature: oc_stop.feature

  # @author cryan@redhat.com
  # @case_id 482218
  Scenario: Check the rc and pod are stopped too after stop deploymentConfig
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-template-sti.json |
    Then the step should succeed
    When I get project deploymentconfig
    Then the step should succeed
    And the output should contain:
      | database |
      | frontend |
    When I get project replicationcontroller
    Then the step should succeed
    And the output should contain:
      | database-1 |
    When I get project pods
    Then the step should succeed
    And the output should contain:
      | ruby-sample-build-1-build |
      | database-1 |
    When I run the :stop client command with:
      | resource | deploymentConfigs |
      | name | database |
    Then the step should succeed
    And the output should contain "deploymentconfig "database" deleted"
    Given I wait for the pod named "database-1-deploy" to die regardless of current status
    When I get project deploymentconfig
    Then the step should succeed
    And the output should not contain:
      | database |
    When I get project replicationcontroller
    Then the step should succeed
    And the output should not contain:
      | database-1 |
    Given I wait for the pod named "database-1-deploy" to die regardless of current status
    And I wait up to 120 seconds for the steps to pass:
    """
    When I get project pods
    Then the step should succeed
    And the output should not contain:
      | database-1 |
    """
