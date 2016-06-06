Feature: admin deployment related features

  # @author xxia@redhat.com
  # @case_id 481683
  @admin @destructive
  Scenario: Prune old deployments by admin command
    Given I have a project
    When I run the :run client command with:
      | name      | mydc              |
      | image     | <%= project_docker_repo %>openshift/hello-openshift |
    Then the step should succeed
    And I wait until the status of deployment "mydc" becomes :complete
    # In sum, 3 complete deployments (the last one is deployed and its status is running)
    And I run the steps 3 times:
    """
    When I run the :deploy client command with:
      | deployment_config | mydc  |
      | latest            |       |
    Then the step should succeed
    And I wait until the status of deployment "mydc" becomes :complete
    """

    When I run the :run client command with:
      | name      | newdc      |
      | image     | <%= project_docker_repo %>openshift/hello-openshift |
      | dry_run   |            |
      | -o        | yaml       |
    Then the step should succeed
    And I save the output to file> dc.yaml
    # In order to make failed deployment
    When I run oc create with "dc.yaml" replacing paths:
      | ["spec"]["strategy"]["rollingParams"]        | {}  |
      | ["spec"]["strategy"]["rollingParams"]["pre"] | { "execNewPod": { "command": [ "/bin/false" ], "containerName": "newdc" }, "failurePolicy": "Abort" }                    |
    Then the step should succeed

    # 2 failed deployment
    Given I wait until the status of deployment "newdc" becomes :failed
    When I run the :deploy client command with:
      | deployment_config | newdc |
      | latest            |       |
    Then the step should succeed
    And I wait until the status of deployment "newdc" becomes :failed

    Given 60 seconds have passed
    When I run the :oadm_prune_deployments admin command with:
      | confirm           | false  |
      | keep_complete     | 2      |
      | keep_failed       | 1      |
      | keep_younger_than | 1m     |
    Then the step should succeed
    And the output should match:
      | [Dd]ry run enabled |
      | mydc-1  |
      | newdc-1 |

    When I run the :get client command with:
      | resource | rc |
    Then the step should succeed
    # --confirm=false does dry-run prune
    And the output should contain:
      | mydc-1  |
      | newdc-1 |

    When I run the :oadm_prune_deployments admin command with:
      | confirm           | true   |
      | keep_complete     | 2      |
      | keep_failed       | 1      |
      | keep_younger_than | 1m     |
    Then the step should succeed

    When I run the :get client command with:
      | resource | rc |
    Then the step should succeed
    # --confirm=true does real prune
    And the output should not contain:
      | mydc-1  |
      | newdc-1 |
    And the output should contain:
      | mydc-2  |
      | mydc-3  |
      | mydc-4  |
      | newdc-2 |

    # Make deployments orphan
    When I run the :delete client command with:
      | object_type       | dc    |
      | object_name_or_id | mydc  |
      | object_name_or_id | newdc |
      | cascade           | false |
    Then the step should succeed

    When I run the :oadm_prune_deployments admin command with:
      | confirm           | false  |
      | orphans           | true   |
      | keep_younger_than | 1m     |
    Then the step should succeed
    And the output should match:
      | [Dd]ry run enabled |
      | mydc-2  |
      | mydc-3  |
      | newdc-2 |

    When I run the :oadm_prune_deployments admin command with:
      | confirm           | true   |
      | orphans           | true   |
      | keep_younger_than | 1m     |
    Then the step should succeed

    When I run the :get client command with:
      | resource | rc |
    Then the step should succeed
    # Orphan deployments are pruned
    And the output should not contain:
      | mydc-2  |
      | mydc-3  |
      | newdc-2 |
    And the output should contain:
      | mydc-4  |

  # @author xxia@redhat.com
  # @case_id 489298
  @admin
  Scenario: Negative/invalid options test for oadm prune deployments
    When I run the :oadm_prune_deployments admin command with:
      | confirm           | false  |
      | keep_complete     | -2.1   |
      | keep_failed       | 1      |
      | keep_younger_than | 1m     |
    Then the step should fail
    And the output should match:
      | [Ii]nvalid argument.*-2.1  |

    When I run the :oadm_prune_deployments admin command with:
      | confirm           | false  |
      | keep_complete     | letter |
      | keep_failed       | 1      |
      | keep_younger_than | 1m     |
    Then the step should fail
    And the output should match:
      | [Ii]nvalid argument.*letter|

    When I run the :oadm_prune_deployments admin command with:
      | confirm           | false  |
      | keep_complete     | 2      |
      | keep_failed       | 1      |
      | keep_younger_than | 1min   |
    Then the step should fail
    And the output should match:
      | [Ii]nvalid argument.*1min  |
