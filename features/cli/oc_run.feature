Feature: oc run related scenarios
  # @author pruan@redhat.com
  # @case_id 499995
  Scenario: Negative test for oc run
    Given I have a project
    And I run the :exec_raw_oc_cmd_for_neg_tests client command with:
      | arg | run |
      | test_do_not_use | -u |
    Then the step should fail
    Then the output should contain:
      | oc run NAME --image=image |
      | Error: unknown shorthand flag: 'u' in -u |
    And I run the :exec_raw_oc_cmd_for_neg_tests client command with:
      | arg | run |
      | test_do_not_use | -l -t |
    Then the step should fail
    Then the output should contain:
      | error: NAME is required for run |
    Then the step should fail
    And I run the :run client command with:
      | name | <%= project.name %> |
      | image |                    |
    Then the step should fail
    And the output should contain:
      | Parameter: image is required |
    # oc run with less options
    And I run the :run client command with:
      | name | newtest |
    Then the step should fail
    And the output should contain:
      | Parameter: image is required |
    And I run the :exec_raw_oc_cmd_for_neg_tests client command with:
      | arg | run |
      | test_do_not_use | --image=test  |
    Then the step should fail
    And the output should contain:
      | error: NAME is required for run |

  # @author xxia@redhat.com
  # @case_id 499994
  Scenario: Create container with oc run command
    Given I have a project
    When I run the :run client command with:
      | name         | mysql                 |
      | image        | mysql                 |
      | dry_run      | true                  |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | dc                 |
      | resource_name | mysql              |
    Then the step should fail
    When I run the :run client command with:
      | name         | webapp                |
      | image        | training/webapp       |
      | -l           | test=one              |
    Then the step should succeed
    And I wait until replicationController "webapp-1" is ready

    When I run the :run client command with:
      | name         | webapp2               |
      | image        | training/webapp       |
      | replicas     | 2                     |
      | -l           | label=webapp2         |
    Then the step should succeed
    And I wait until replicationController "webapp2-1" is ready

    When I run the :run client command with:
      | name         | webapp3               |
      | image        | training/webapp       |
      | overrides    | {"apiVersion":"v1","spec":{"replicas":2}} |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | dc                 |
      | resource_name | webapp3            |
      | output        | yaml               |
    Then the step should succeed
    And the output should contain:
      | replicas: 2       |

    When I run the :run client command with:
      | name         | webapp4               |
      | image        | training/webapp       |
      | attach       | true                  |
      | restart      | Never                 |
      | _timeout     | 15                    |
    Then the step should have timed out
    And the output should match:
      | [Ww]aiting for pod .*webapp4 to be running       |
    When I run the :run client command with:
      | name         | webapp5               |
      | image        | training/webapp       |
      | -i           | true                  |
      | tty          | true                  |
      | restart      | Never                 |
      | _timeout     | 15                    |
    Then the step should have timed out
    And the output should match:
      | [Ww]aiting for pod .*webapp5 to be running       |

  # @author pruan@redhat.com
  # @case_id 510405
  Scenario: oc run can create dc, standalone rc, standalone pod
    Given I have a project
    When I run the :run client command with:
      | name         | myrun                 |
      | image        | aosqe/hello-openshift |
    Then the step should succeed
    Given I wait until the status of deployment "myrun" becomes :running
    When I run the :get client command with:
      | resource | dc |
    Then the step should succeed
    And the output should contain:
      | myrun |
    When I run the :get client command with:
      | resource | rc |
    Then the step should succeed
    And the output should contain:
      | myrun-1 |
    And the output should contain:
      | myrun |
    When I run the :get client command with:
      | resource | pod |
    Then the step should succeed
    And the output should contain:
      | myrun-1- |
    # Create a standalone rc
    When I run the :run client command with:
      | name         | myrun-rc              |
      | image        | aosqe/hello-openshift |
      | generator    | run-controller/v1 |
    Then the step should succeed
    Given I wait until replicationController "myrun-rc" is ready
    When I run the :get client command with:
      | resource | dc |
    Then the step should succeed
    And the output should not contain:
      | myrun-rc |
    When I run the :get client command with:
      | resource | pod |
    Then the step should succeed
    And the output should contain:
      | myrun-rc-|
    # Create a standalone pod
    When I run the :run client command with:
      | name         | myrun-pod             |
      | image        | aosqe/hello-openshift |
      | generator    | run-pod/v1 |
    Then the step should succeed
    When I run the :get client command with:
      | resource | dc |
    Then the step should succeed
    And the output should not contain:
      | myrun-pod |
    When I run the :get client command with:
      | resource | rc |
    Then the step should succeed
    And the output should not contain:
      | myrun-pod |
    When I run the :get client command with:
      | resource | pod |
    Then the step should succeed
    And the output should contain:
      | myrun-pod |

  # @author yadu@redhat.com
  # @case_id 510408
  Scenario: oc run has different default creation types when using different 'restart' option
    Given I have a project
    When I run the :run client command with:
      | name  | test-a                |
      | image | aosqe/hello-openshift |
    Then the step should succeed
    When I run the :get client command with:
      | resource | dc |
    Then the step should succeed
    And the output should contain:
      | test-a |
    When I run the :run client command with:
      | name    | test-b                |
      | image   | aosqe/hello-openshift |
      | restart | OnFailure             |
    Then the step should succeed
    When I run the :get client command with:
      | resource | pod |
    Then the step should succeed
    And the output should contain:
      | test-b |
    When I run the :run client command with:
      | name    | test-c                |
      | image   | aosqe/hello-openshift |
      | restart | Never                 |
    Then the step should succeed
    When I run the :get client command with:
      | resource | pod |
    Then the step should succeed
    And the output should contain:
      | test-c |
    # Negative test
    When I run the :run client command with:
      | name    | test-f                |
      | image   | aosqe/hello-openshift |
      | restart | Invalid               |
    Then the step should fail
    And the output should contain:
      | invalid restart policy |
    When I run the :run client command with:
      | name     | test-n                |
      | image    | aosqe/hello-openshift |
      | restart  | Never                 |
      | replicas | 2                     |
    Then the step should fail
    And the output should contain:
      | error |
    When I run the :run client command with:
      | name     | test-m                |
      | image    | aosqe/hello-openshift |
      | restart  | Never                 |
      | replicas | 1                     |
    Then the step should succeed
    When I run the :get client command with:
      | resource | pod |
    Then the step should succeed
    And the output should contain:
      | test-m |

  # @author yadu@redhat.com
  # @case_id 510407
  Scenario: oc run can set various fields in the pod container
    Given I have a project
    When I run the :run client command with:
      | name      | myrun-pod             |
      | image     | aosqe/hello-openshift |
      | generator | run-pod/v1            |
      | env       | MYENV1=v1,MYENV2=v2   |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | pod        |
      | resource_name | myrun-pod  |
      | o             | json       |
    Then the step should succeed
    And the output should contain:
      | "name": "MYENV1" |
      | "value": "v1     |
      | "name": "MYENV2" |
      | "value": "v2"    |
    When I run the :run client command with:
      | name      | myrun-pod-2             |
      | image     | aosqe/hello-openshift   |
      | generator | run-pod/v1              |
      | limits    | cpu=200m,memory=512Mi   |
      | requests  | cpu=100m,memory=256Mi   |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | pod          |
      | resource_name | myrun-pod-2  |
      | o             | json         |
    Then the step should succeed
    And the output should contain:
      |  "limits":          |
      |  "memory": "512Mi"  |
    When I run the :run client command with:
      | name      | myrun-pod-3             |
      | image     | aosqe/hello-openshift   |
      | generator | run-pod/v1              |
      | restart   | OnFailure               |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | pod          |
      | resource_name | myrun-pod-3  |
      | o             | json         |
    Then the step should succeed
    And the output should contain:
      |  "restartPolicy": "OnFailure" |
    When I run the :run client command with:
      | name      | myrun-pod-4             |
      | image     | aosqe/hello-openshift   |
      | generator | run-pod/v1              |
      | port      | 8888                    |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | pod          |
      | resource_name | myrun-pod-4  |
      | o             | json         |
    And the output should contain:
      |  "containerPort": 8888  |
    When I run the :run client command with:
      | name      | test                    |
      | image     | aosqe/hello-openshift   |
      | replicas  | 2                       |
      | overrides | {"apiVersion":"v1","spec":{"replicas":3}} |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | dc     |
      | resource_name | test   |
      | o             | json   |
    Then the step should succeed
    And the output should contain:
      | "replicas": 3 |

  # @author cryan@redhat.com
  # @case_id 508037
  Scenario: Run container via cli with invalid format specifying cpu/memory request/limit
    Given I have a project
    When I run the :run client command with:
      | name | nginx |
      | image | nginx |
      | replicas | 1 |
      | requests | cpu100m,memory=512Mi |
    Then the step should fail
    And the output should contain "Invalid argument syntax"
    When I run the :run client command with:
      | name | nginx |
      | image | nginx |
      | replicas | 2 |
      | limits | cpu100m\&memory=512Mi |
    Then the step should fail
    And the output should contain "Invalid value"
    When I run the :run client command with:
      | name | nginx |
      | image | nginx |
      | replicas | 3 |
      | requests | cpu= |
    Then the step should fail
    And the output should contain "quantities must match the regular expression"
    When I run the :run client command with:
      | name | nginx |
      | image | nginx |
    Then the step should succeed
