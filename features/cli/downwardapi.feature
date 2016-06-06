Feature: Downward API

  # @author qwang@redhat.com
  # @case_id 509097
  Scenario: Pods can get IPs via downward API under race condition
    Given I have a project
    When I run the :create client command with:
      | filename  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/downwardapi/tc509097/pod-downwardapi-env.yaml |
    Then the step should succeed
    Given the pod named "downwardapi-env" becomes ready
    When I run the :get client command with:
      | resource | pods |
    Then the output should contain:
      | NAME            |
      | downwardapi-env |
    When  I run the :describe client command with:
      | resource | pod             |
      | name     | downwardapi-env |
    Then the output should match:
      | Status:\\s+Running |
      | Ready\\s+True      |
    When I run the :exec client command with:
      | pod          | downwardapi-env |
      | exec_command | env             |
    Then the output should contain "MYSQL_POD_IP=1"

  # @author cryan@redhat.com
  # @case_id 483203
  Scenario: downward api pod name and pod namespace as env variables
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/downwardapi/tc483203/downward-example.yaml |
    Then the step should succeed
    And the pod named "dapi-test-pod" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | dapi-test-pod |
    Then the step should succeed
    And the output should contain:
      | POD_NAME=dapi-test-pod |
      | POD_NAMESPACE=<%= project.name %> |
