Feature: scaling related scenarios
  # @author pruan@redhat.com
  # @case_id 482264
  Scenario: Scale replicas via replicationcontrollers and deploymentconfig
    Given I have a project
    And I create a new application with:
      | image_stream | openshift/perl:5.20 |
      | name         | myapp                  |
      | code         | https://github.com/openshift/sti-perl |
      | context_dir  | 5.20/test/sample-test-app/            |
    Then the step should succeed
    When I expose the "myapp" service
    Then the step should succeed
    Given I wait for the "myapp" service to become ready
    When I get project replicationcontroller as JSON
    And evaluation of `@result[:parsed]['items'][0]['metadata']['name']` is stored in the :rc_name clipboard
    When I run the :describe client command with:
      | resource | replicationcontrollers |
      | name     | <%= cb.rc_name %>      |
    Then the step should succeed
    Then the output should contain:
      | <%= "Replicas:\\t1 current / 1 desired" %> |
    Then I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | <%= cb.rc_name %>      |
      | replicas | 2                      |
    And I wait until number of replicas match "2" for replicationController "<%= cb.rc_name %>"
    # get dc name
    When I get project deploymentconfig as JSON
    And evaluation of `@result[:parsed]['items'][0]['metadata']['name']` is stored in the :dc_name clipboard
    Then I run the :scale client command with:
      | resource | deploymentconfig  |
      | name     | <%= cb.dc_name %> |
      | replicas | 3                 |
    Then the step should succeed
    And I wait until number of replicas match "3" for replicationController "<%= cb.rc_name %>"
    # scale down
    Then I run the :scale client command with:
      | resource | deploymentconfig  |
      | name     | <%= cb.dc_name %> |
      | replicas | 2                 |
    Then the step should succeed
    And I wait until number of replicas match "2" for replicationController "<%= cb.rc_name %>"
    Then I run the :scale client command with:
      | resource | deploymentconfig  |
      | name     | <%= cb.dc_name %> |
      | replicas | 0                 |
    Then the step should succeed
    And I wait until number of replicas match "0" for replicationController "<%= cb.rc_name %>"

    Then I run the :scale client command with:
      | resource | deploymentconfig  |
      | name     | <%= cb.dc_name %> |
      | replicas | -3                |
    Then the step should fail
    And the output should contain:
      | error: --replicas=COUNT |

  # @author xxia@redhat.com
  # @case_id 470697
  Scenario: Pod will automatically be created by replicationcontroller when it was deleted
    Given I have a project
    And I run the :run client command with:
      | name         | myrun                 |
      | image        | yapei/hello-openshift |
      | generator    | run-controller/v1     |
      | -l           | rc=myrun              |
    Then the step should succeed

    When I wait until replicationController "myrun" is ready
    And I run the :get client command with:
      | resource | pod                |
      | l        | rc=myrun           |
    Then the step should succeed
    And the output should contain "myrun-"

    Given evaluation of `project.pods(by: user)[0].name` is stored in the :pod_name clipboard
    When I run the :delete client command with:
      | object_type | pod             |
      | l           | rc=myrun        |
    Then the step should succeed

    When I wait for the resource "pod" named "<%= cb.pod_name %>" to disappear
    And I run the :get client command with:
      | resource | pod                |
      | l        | rc=myrun           |
    Then the step should succeed
    And the output should contain "myrun-"
    And the output should not contain "<%= cb.pod_name %>"

  # @author pruan@redhat.com
  # @case_id 511599
  Scenario: Scale up/down jobs
    Given I have a project
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc511599/job.yaml |
    And I run the :scale client command with:
      | resource | jobs |
      | name     | pi   |
      | replicas | 5    |
    Then the step should succeed
    And I run the :describe client command with:
      | resource | jobs |
    Then the output should match:
      | Parallelism:\s+5 |
    And I run the :scale client command with:
      | resource | jobs |
      | name     | pi   |
      | replicas | 1    |
    Then the step should succeed
    And I run the :describe client command with:
      | resource | jobs |
    Then the output should match:
      | Parallelism:\s+1 |
      | 1\s+Running      |
    And I run the :scale client command with:
      | resource | jobs |
      | name     | pi   |
      | replicas | 25   |
    Then the step should succeed
    And I run the :describe client command with:
      | resource | jobs |
    Then the output should match:
      | Parallelism:\s+25 |

  # @author yinzhou@redhat.com
  # @case_id 521567
  Scenario: Only scale the dc can scale the active deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/testhook.json |
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :complete
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            ||
    Then the step should succeed
    And I run the :deploy client command with:
      | deployment_config | hooks |
      | cancel            ||
    Then the step should succeed
    And the output should match:
      | [Cc]ancelled |
    And I wait until the status of deployment "hooks" becomes :failed
    Then I run the :scale client command with:
      | resource | ReplicationController |
      | name     | hooks-1     |
      | replicas | 2                |
    Given I wait until number of replicas match "2" for replicationController "hooks-1"
    Given I wait until number of replicas match "1" for replicationController "hooks-1"
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | hooks            |
      | replicas | 2                |
    Given I wait until number of replicas match "2" for replicationController "hooks-1"
    When I run the :get client command with:
      | resource      | deploymentConfig |
      | resource_name | hooks |
      | o             | json |
    Then the output should contain:
      | "replicas": 2          |

  # @author yinzhou@redhat.com
  # @case_id 519821
  @admin
  Scenario: [openshift-sme]When rolling deployments the pod should shutdown gracefully
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment-with-shutdown-gracefully.json |
    Then the step should succeed
    Given I wait until the status of deployment "nettest" becomes :complete
    And a pod becomes ready with labels:
      | app=nettest |
    Then evaluation of `pod.name` is stored in the :pod1_name clipboard
    Then evaluation of `pod.ip` is stored in the :pod1_ip clipboard
    When I run the :deploy client command with:
      | deployment_config | nettest |
      | latest            ||
    Then the step should succeed
    Given I wait until the status of deployment "nettest" becomes :complete
    Given the pod named "<%= cb.pod1_name %>" status becomes :running
    And I select a random node's host
    When I run commands on the host:
      | curl <%= cb.pod1_ip %>:8080/status -vv|
    Then the step should succeed
    And the expression should be true> @result[:response].include?("200 OK")
