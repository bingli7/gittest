Feature: rolling deployment related scenarios
  # @author pruan@redhat.com
  # @case_id 503866
  Scenario: Rolling-update pods with set maxSurge to 0
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/rolling.json |
    #And I wait until replicationController "hooks-1" is ready
    And I wait for the pod named "hooks-1-deploy" to die
    Then I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | hooks-1                |
      | replicas | 3                     |
    #And I wait for the pod named "hooks-1-deploy" to die
    And I replace resource "dc" named "hooks":
      | maxSurge: 25% | maxSurge: 0 |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            | true  |
    And the pod named "hooks-2-deploy" becomes ready
    Given I collect the deployment log for pod "hooks-2-deploy" until it disappears
    And the output should contain:
      | keep 2 pods available, don't exceed 3 pods |
    And I replace resource "dc" named "hooks":
      | maxUnavailable: 25% | maxUnavailable: 50% |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            | true  |
    And the pod named "hooks-3-deploy" becomes ready
    Given I collect the deployment log for pod "hooks-3-deploy" until it disappears
    And the output should contain:
      | keep 2 pods available|
    And I replace resource "dc" named "hooks":
      | maxUnavailable: 50% | maxUnavailable: 80% |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            | true  |
    And the pod named "hooks-4-deploy" becomes ready
    Given I collect the deployment log for pod "hooks-4-deploy" until it disappears
    And the output should contain:
      | keep 1 pods available |

  # @author pruan@redhat.com
  # @case_id 503864
  Scenario: Rolling-update an invalid value of pods - Negative test
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/rolling.json |
    And I wait for the pod named "hooks-1-deploy" to die
    Then I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | hooks-1                |
      | replicas | 10                     |
    And all pods in the project are ready
    And I replace resource "dc" named "hooks":
      | maxSurge: 25% | maxSurge: -10 |
    Then the step should fail
    And the output should match:
      | .*nvalid value.*-10.*must be non-negative |

  # @author pruan@redhat.com
  # @case_id 503867
  Scenario: Rolling-update pods with set maxUnavabilable to 0
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/rolling.json |
    And I wait for the pod named "hooks-1-deploy" to die
    Then I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | hooks-1                |
      | replicas | 3                     |
    And all pods in the project are ready
    And I replace resource "dc" named "hooks":
      | maxSurge: 25%       | maxSurge: 10%       |
      | maxUnavailable: 25% | maxUnavailable: 0 |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            | true  |
    And the pod named "hooks-2-deploy" becomes ready
    Given I collect the deployment log for pod "hooks-2-deploy" until it disappears
    And the output should contain:
      | keep 3 pods available, don't exceed 4 pods |
    And I replace resource "dc" named "hooks":
      | maxSurge: 10% | maxSurge: 30% |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            | true  |
    And the pod named "hooks-3-deploy" becomes ready
    Given I collect the deployment log for pod "hooks-3-deploy" until it disappears
    And the output should contain:
      | keep 3 pods available, don't exceed 4 pods |
    And I replace resource "dc" named "hooks":
      | maxSurge: 30% | maxSurge: 60% |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            | true  |
    And the pod named "hooks-4-deploy" becomes ready
    Given I collect the deployment log for pod "hooks-4-deploy" until it disappears
    And the output should contain:
      | keep 3 pods available, don't exceed 5 pods |

  # @author pruan@redhat.com
  # @case_id 503865,483171
  Scenario: Rolling-update pods with default value for maxSurge/maxUnavailable
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/rolling.json |
    And I wait for the pod named "hooks-1-deploy" to die
    Then I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | hooks-1                |
      | replicas | 3                     |
    And all pods in the project are ready
    And I wait up to 120 seconds for the steps to pass:
    """
    And I run the :get client command with:
      | resource | dc |
      | resource_name | hooks |
      | output | yaml |
    Then the output should contain:
      | replicas: 3  |
      | maxSurge: 25% |
      | maxUnavailable: 25%  |
    """
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            | true  |
    Then the step should succeed
    And the pod named "hooks-2-deploy" becomes ready
    Given I collect the deployment log for pod "hooks-2-deploy" until it disappears
    And the output should contain:
      | keep 3 pods available, don't exceed 4 pods |
    And I replace resource "dc" named "hooks":
      | maxUnavailable: 25% | maxUnavailable: 1 |
      | maxSurge: 25% | maxSurge: 2             |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            | true  |
    Then the step should succeed
    And the pod named "hooks-3-deploy" becomes ready
    Given I collect the deployment log for pod "hooks-3-deploy" until it disappears
    And the output should contain:
      | keep 2 pods available, don't exceed 5 pods |

  # @author xiaocwan@redhat.com
  # @case_id 454716
  Scenario: Rollback to one component of previous deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Recreate"     |
      | "type": "ConfigChange" |
      | "replicas": 1 |

    When I run the :replace client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/updatev1.json |
    Then the step should succeed

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Rolling"     |
      | "type": "ImageChange" |
      | "replicas": 2 |

    ## post rest request for curl new json
    When I perform the :rollback_deploy rest request with:
      | project_name            | <%= project.name %> |
      | deploy_name             | hooks-1 |
      | includeTriggers         | false |
      | includeTemplate         | true  |
      | includeReplicationMeta  | false |
      | includeStrategy         | false |
    Then the step should succeed
    And the output should contain:
      | 201 |
    When I save the output to file>rollback.json
    And I run the :replace client command with:
      | f | rollback.json |
    Then the step should succeed
    And the output should contain:
      | replaced |

  # @author xiaocwan@redhat.com
  # @case_id 454717
  Scenario: [origin_runtime_509]Rollback to three components of previous deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Recreate"     |
      | "type": "ConfigChange" |
      | "replicas": 1 |

    When I run the :replace client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/updatev1.json |
    Then the step should succeed

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Rolling"     |
      | "type": "ImageChange" |
      | "replicas": 2 |

    ## post rest request for curl new json
    When I perform the :rollback_deploy rest request with:
      | project_name            | <%= project.name %> |
      | deploy_name             | hooks-1 |
      | includeTriggers         | false |
      | includeTemplate         | true  |
      | includeReplicationMeta  | true  |
      | includeStrategy         | true  |
    Then the step should succeed
    And the output should contain:
      | 201 |

    When I save the output to file>rollback.json
    And I run the :replace client command with:
      | f | rollback.json |
    Then the step should succeed
    And the output should contain:
      | replaced |

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Recreate"     |
      | "replicas": 1 |

  # @author xiaocwan@redhat.com
  # @case_id 454718
  Scenario: [origin_runtime_509]Rollback to two components of previous deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Recreate"     |
      | "type": "ConfigChange" |
      | "replicas": 1 |

    When I run the :replace client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/updatev1.json |
    Then the step should succeed

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Rolling"     |
      | "type": "ImageChange" |
      | "replicas": 2 |

    ## post rest request for curl new json
    When I perform the :rollback_deploy rest request with:
      | project_name            | <%= project.name %> |
      | deploy_name             | hooks-1 |
      | includeTriggers         | false |
      | includeTemplate         | true  |
      | includeReplicationMeta  | true  |
      | includeStrategy         | false |
    Then the step should succeed
    And the output should contain:
      | 201 |

    When I save the output to file>rollback.json
    And I run the :replace client command with:
      | f | rollback.json |
    Then the step should succeed
    And the output should contain:
      | replaced |

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "replicas": 1 |

  # @author xiaocwan@redhat.com
  # @case_id 454715
  Scenario: [origin_runtime_509]Rollback to all components of previous deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Recreate"     |
      | "type": "ConfigChange" |
      | "replicas": 1 |

    When I run the :replace client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/updatev1.json |
    Then the step should succeed

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Rolling"     |
      | "type": "ImageChange" |
      | "replicas": 2 |

    ## post rest request for curl new json
    When I perform the :rollback_deploy rest request with:
      | project_name            | <%= project.name %> |
      | deploy_name             | hooks-1 |
      | includeTriggers         | true  |
      | includeTemplate         | true  |
      | includeReplicationMeta  | true  |
      | includeStrategy         | true  |
    Then the step should succeed
    And the output should contain:
      | 201 |
    When I save the output to file>rollback.json
    And I run the :replace client command with:
      | f | rollback.json |
    Then the step should succeed
    And the output should contain:
      | replaced |

    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should contain:
      |NAME                   |
      | hooks                 |
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             |  json |
    Then the output should contain:
      | "type": "Recreate"     |
      | ConfigChange |
      | "replicas": 1 |
