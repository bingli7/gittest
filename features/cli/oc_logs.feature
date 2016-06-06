Feature: oc logs related features
  # @author wzheng@redhat.com
  # @case_id 438848
  Scenario: Get buildlogs with invalid parameters
    Given I have a project
    When I run the :logs client command with:
      | resource_name | 123 |
    Then the step should fail
    And the output should contain "Error from server: pods "123" not found"
    When I run the :logs client command with:
      | resource_name |   |
    Then the step should fail
    And the output should contain "resource name may not be empty"

  # @author xxia@redhat.com
  # @case_id 512022
  Scenario: oc logs for a resource with miscellaneous options
    Given I have a project
    When I create a new application with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    When I run the :create client command with:
      | f    | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/double_containers.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json |
    Then the step should succeed

    Given the pod named "doublecontainers" becomes ready
    When I run the :logs client command with:
      | resource_name    | pod/doublecontainers |
      | c                | hello-openshift      |
    Then the step should succeed
    When I run the :logs client command with:
      | resource_name    | pod/doublecontainers |
      | c                | no-this              |
    Then the step should fail

    Given the pod named "hello-openshift" becomes ready
    When I run the :logs client command with:
      | resource_name    | pod/hello-openshift  |
      | limit-bytes      | 5                    |
    Then the step should succeed
    And the expression should be true> @result[:response].length == 5

    # Waiting ensures we could see logs in case the pod has not printed logs yet.
    Given I wait for the steps to pass:
    """
    When I run the :logs client command with:
      | resource_name    | pod/hello-openshift  |
      | timestamps       |                      |
      | since            | 3h                   |
    Then the step should succeed
    And the output should match:
      | T[0-9:.]+Z |
    And evaluation of `@result[:response]` is stored in the :logs clipboard
    """
    And 2 seconds have passed
    # Once met cucumber ran fast: previous `oc logs` printed "2016-03-07T06:18:33...Z serving on 8080", and following `oc logs` was run at "[06:18:34] INFO> Shell Commands" and printed the same logs
    # Thus, "2 seconds have passed" could make scripts robuster
    When I run the :logs client command with:
      | resource_name    | pod/hello-openshift  |
      | timestamps       |                      |
      | since            | 1s                   |
    Then the step should succeed
    # Only logs newer than given time will be shown
    And the output should not contain "<%= cb.logs %>"
    When I run the :logs client command with:
      | resource_name    | pod/hello-openshift  |
      | timestamps       |                      |
      | since-time       | 2000-01-01T00:00:00Z |
    Then the step should succeed
    And the output should match:
      | T[0-9:.]+Z |

    # Only one of "--since" and "--since-time" can be used
    When I run the :logs client command with:
      | resource_name    | pod/hello-openshift  |
      | since            | 2m                   |
      | since-time       | 2000-01-01T00:00:00Z |
    Then the step should fail

    Given the "ruby-sample-build-1" build finished
    When I run the :logs client command with:
      | resource_name    | bc/ruby-sample-build |
      | version          | 1                    |
    Then the step should succeed
    When I run the :logs client command with:
      | resource_name    | bc/ruby-sample-build |
      | version          | 5                    |
    Then the step should fail
    And the output should contain:
      | not found |

    When I run the :logs client command with:
      | resource_name    | pod/hello-openshift  |
      | since-time       | #@234                |
    Then the step should fail

  # @author xiaocwan@redhat.com
  # @case_id 519497
  Scenario: Debug pod with oc debug
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/dc-with-two-containers.yaml |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=dctest-1 |
    When I run the :debug client command with:
      | resource      | dc/dctest   |
    Then the step should succeed
    And the output should match:
      | [Dd]ebugging with pod.*     |
      | [Ww]aiting for pod to start |
      | [Rr]emoving debug pod       |

  # @author xiaocwan@redhat.com
  # @case_id 519503
  Scenario: Debug the resource with keeping the original pod info
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/2ca50e6cf3131acd17feb6553a2551974be3ffaa/test/integration/fixtures/test-deployment-config.yaml |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=test-deployment-config-1 |
    When I run the :debug client command with:
      | resource         | dc/test-deployment-config |
      | keep_annotations |        |
      | o                | yaml   |
    Then the step should succeed
    And the output should match:
      | openshift.io/deployment-config.latest-version:.*1              |
      | openshift.io/deployment-config.name:\\stest-deployment-config  |
      | openshift.io/deployment.name:\\s+test-deployment-config-1      |

    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod-with-probe.yaml |
    Then the step should succeed
    When the pod named "hello-openshift" status becomes :running
    And I run the :debug client command with:
      | resource       | pod/hello-openshift |
      | keep_liveness  | |
      | keep_readiness | |
      | o              | yaml               |
    Then the step should succeed
    And the output should match:
      | livenessProbe:\\s+failureThreshold: |

  # @author xiaocwan@redhat.com
  # @case_id 519561
  Scenario: Use oc debug with misc flags
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/dc-with-two-containers.yaml |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=dctest-1 |
    When I run the :debug client command with:
      | resource       | dc/dctest       |
      | c              | dctest-2        |
      | one_container  | true            |
      | o              | json            |
    Then the step should succeed
    And the output should match:
      |  "name":\\s+"dctest-2" |
    And the output should not match:
      |  "name":\\s+"dctest-1" |
    When I run the :debug client command with:
      | resource       | dc/dctest            |
      | node_name      | <%= pod.node_name(user: user) %>|
      | oc_opts_end    | |
      | exec_command   | /bin/env             |
    Then the output should match:
      | [Dd]ebugging with pod                 |
      | [Ww]aiting for pod to start           |
      | PATH=                                 |
      | HOSTNAME=                             |
      | [Rr]emoving debug pod                 |
    When I run the :debug client command with:
      | resource       | dc/dctest            |
      | node_name      | invalidnode          |
      | oc_opts_end    | |
      | exec_command   | /bin/env             |
    Then the output should match:
      | [Ee]rror                              |
      | [Pp]ods.*not found                    |
    Given I get project pod as YAML
    And I save the output to file>pod.yaml
    When I run the :debug client command with:
      | f              | pod.yaml             |
      | oc_opts_end    | |
      | exec_command   | /bin/env             |
    Then the step should succeed
    And the output should match:
      | [Dd]ebugging with pod                 |
      | [Ww]aiting for pod to start           |
      | PATH=                                 |
      | HOSTNAME=                             |
      | [Rr]emoving debug pod                 |