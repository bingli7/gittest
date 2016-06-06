Feature: oc_scale.feature

  # @author cryan@redhat.com
  # @case_id 482265
  # @bug_id 1276602
  Scenario: Scale replicas in specific conditions
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | openshift/perl:5.16 |
      | code | https://github.com/openshift/sti-perl |
      | l | app=test-perl |
      | context_dir | 5.16/test/sample-test-app/ |
      | name | myapp |
    Then the step should succeed
    Given I wait until replicationController "myapp-1" is ready
    When I run the :scale client command with:
      | resource| replicationcontrollers |
      | name | myapp-1 |
      | current_replicas | 2 |
      | replicas | 3 |
    Then the step should fail
    And the output should contain "Expected"
    Given I wait until number of replicas match "1" for replicationController "myapp-1"
    When I run the :scale client command with:
      | resource| replicationcontrollers |
      | name | myapp-1 |
      | replicas | 2 |
    Then the step should succeed
    Given I wait until number of replicas match "2" for replicationController "myapp-1"
    When I run the :scale client command with:
      | resource| replicationcontrollers |
      | name | myapp-1 |
      | current_replicas | 2 |
      | replicas | 3 |
    Then the step should succeed
    Given I wait until number of replicas match "3" for replicationController "myapp-1"
    And I run the :get client command with:
      | resource | replicationcontrollers |
      | o | json |
    And evaluation of `JSON.parse(@result[:response])` is stored in the :jsonout clipboard
    And evaluation of `cb.jsonout['items'][0]['metadata']['resourceVersion']` is stored in the :resver clipboard
    When I run the :scale client command with:
      | resource| replicationcontrollers |
      | name | myapp-1 |
      | resource_ver | <%= cb.resver %> |
      | replicas | 3 |
    Then the step should succeed
    When I run the :scale client command with:
      | resource| replicationcontrollers |
      | name | myapp-1 |
      | replicas | 2 |
      | timeout | 20s |
    Then the step should succeed
    Given I wait until number of replicas match "2" for replicationController "myapp-1"
    When I run the :scale client command with:
      | resource| deploymentconfigs |
      | name | myapp |
      | replicas | 2 |
      | timeout | 20s |
    Then the step should succeed
    Given I wait until number of replicas match "2" for replicationController "myapp-1"
