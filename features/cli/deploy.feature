Feature: deployment related features

  # @author: xxing@redhat.com
  # @case_id: 483193
  Scenario: Restart a failed deployment by oc deploy
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    # Wait and make the cancel succeed stably
    And I wait until the status of deployment "hooks" becomes :running
    When  I run the :deploy client command with:
      | deployment_config | hooks |
      | cancel            ||
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :failed
    When I run the :deploy client command with:
      | deployment_config | hooks |
    Then the output should match "hooks.*#1.*failed"
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | retry             ||
    Then the output should contain "etried #1"
    And I wait until the status of deployment "hooks" becomes :complete
    When I run the :deploy client command with:
      | deployment_config | hooks |
    Then the output should match "hooks.*#1.*deployed"

  # @author: xxing@redhat.com
  # @case_id: 457713
  Scenario: CLI rollback dry run
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    When I run the :replace client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/updatev1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | dc |
      | resource_name | hooks |
    Then the output should match:
      | hooks\\s+2\\s+2\\s+image.*|
    When I run the :rollback client command with:
      | deployment_name | hooks-1 |
      | dry_run         ||
    Then the output should match:
      | Strategy:\\s+Rolling |
    When I run the :rollback client command with:
      | deployment_name         | hooks-1 |
      | dry_run                 ||
      | change_scaling_settings ||
      | change_strategy         ||
      | change_triggers         ||
    Then the output should match:
      | Triggers:\\s+Config   |
      | Strategy:\\s+Recreate |
      | Replicas:\\s+1        |

  # @author: xxing@redhat.com
  # @case_id: 489262
  Scenario: Can't stop a deployment in Complete status
    Given I have a project
    When I run the :new_app client command with:
      | docker_image   | <%= project_docker_repo %>openshift/deployment-example |
    Then the step should succeed
    # Wait till the deploy complete
    And the pod named "deployment-example-1-deploy" becomes ready
    Given I wait for the pod named "deployment-example-1-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | deployment-example |
    Then the output should match "deployment-example.+#1.+deployed"
    When  I run the :describe client command with:
      | resource | dc |
      | name     | deployment-example |
    Then the output should match:
      | Deployment\\s+#1.*latest |
      | Status:\\s+Complete       |
      | Pods Status:\\s+1 Running |
    When I run the :deploy client command with:
      | deployment_config | deployment-example |
      | cancel            ||
    Then the output should contain "No deployments are in progress"
    When I run the :deploy client command with:
      | deployment_config | deployment-example |
    Then the output should match "deployment-example.+#1.+deployed"
    When I run the :describe client command with:
      | resource | dc |
      | name     | deployment-example |
    Then the output should match:
      | Status:\\s+Complete |
    When I run the :deploy client command with:
      | deployment_config | deployment-example |
      | retry             ||
    Then the output should contain:
      | #1 is Complete; only failed deployments can be retried        |
      | You can start a new deployment using the --latest option      |
    When I run the :get client command with:
      | resource | pod |
    Then the output should not contain:
      | deployment-example-1-deploy   |

  # @author xxing@redhat.com
  # @case_id 454714
  Scenario: Negative test for rollback
    Given I have a project
    When I run the :rollback client command with:
      | deployment_name | non-exist |
    Then the output should contain:
      | error: non-exist is not a valid deployment or deploymentconfig |
    When I run the :rollback client command with:
      | deployment_name         | non-exist |
      | change_strategy         ||
      | change_triggers         ||
      | change_scaling_settings ||
    Then the output should contain:
      | error: non-exist is not a valid deployment or deploymentconfig |
    When I run the :rollback client command with:
      | deployment_name         | non-exist |
      | change_strategy         ||
      | change_triggers         ||
      | change_scaling_settings ||
      | dry_run                 ||
    Then the output should contain:
      | error: non-exist is not a valid deployment or deploymentconfig |
    When I run the :rollback client command with:
      | deployment_name         | non-exist |
      | output                  | yaml      |
      | change_strategy         ||
      | change_triggers         ||
      | change_scaling_settings ||
    Then the output should contain:
      | error: non-exist is not a valid deployment or deploymentconfig |

  # @author xxing@redhat.com
  # @case_id 491013
  Scenario: Manually make deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/manual.json |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | hooks |
    Then the output should match "hooks.+#1.+waiting for manual"
    When I run the :get client command with:
      | resource      | dc |
      | resource_name | hooks |
    Then the output should match:
      | hooks\\s+0 |
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            ||
    Then the output should contain "Started deployment #1"
    # Wait the deployment till complete
    And the pod named "hooks-1-deploy" becomes ready
    Given I wait for the pod named "hooks-1-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | hooks |
    Then the output should match "hooks.+#1.+deployed"
    When I run the :get client command with:
      | resource      | dc |
      | resource_name | hooks |
    Then the output should match:
      | hooks\\s+1                        |
    # Make the edit action
    When I run the :get client command with:
      | resource      | dc |
      | resource_name | hooks |
      | o             | json |
    And I save the output to file>hooks.json
    And I replace lines in "hooks.json":
      | Recreate | Rolling |
    When I run the :replace client command with:
      | f | hooks.json |
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            ||
    Then the output should contain "Started deployment #2"
    When I run the :get client command with:
      | resource      | dc |
      | resource_name | hooks |
      | o             | yaml |
    Then the output should contain:
      | type: Rolling |

  # @author xxing@redhat.com
  # @case_id 457715
  Scenario: CLI rollback output to file
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    When I run the :replace client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/updatev1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | deploymentConfig |
      | resource_name | hooks |
    Then the output should match:
      | hooks\\s+2\\s+2\\s+image.*|
    When I run the :rollback client command with:
      | deployment_name         | hooks-1 |
      | output                  | json  |
    #Show the container config only
    Then the output should match:
      | "value": "Plqe5Wev" |
    When I run the :rollback client command with:
      | deployment_name         | hooks-1 |
      | output                  | yaml  |
      | change_strategy         ||
      | change_triggers         ||
      | change_scaling_settings ||
    Then the output should match:
      | replicas:\\s+1        |
      | type:\\s+Recreate     |
      | value:\\s+Plqe5Wev    |
      | type:\\s+ConfigChange |

  # @author xxing@redhat.com
  # @case_id 457712 457717 457718
  Scenario Outline: CLI rollback two more components of deploymentconfig
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | deploymentConfig |
      | resource_name | hooks |
      | o             | json |
    Then the output should contain:
      | "type": "Recreate"     |
      | "type": "ConfigChange" |
      | "replicas": 1          |
      | "value": "Plqe5Wev"    |
    When I run the :replace client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/updatev1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | deploymentConfig |
      | resource_name | hooks |
      | o             | json |
    Then the output should contain:
      | "type": "Rolling"         |
      | "type": "ImageChange"     |
      | "replicas": 2             |
      | "value": "Plqe5Wevchange" |
    When I run the :rollback client command with:
      | deployment_name         | hooks-1 |
      | change_triggers         ||
      | change_scaling_settings | <change_scaling_settings> |
      | change_strategy         | <change_strategy> |
    Then the output should contain:
      | #3 rolled back to hooks-1 |
    And the pod named "hooks-3-deploy" becomes ready
    Given I wait for the pod named "hooks-3-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | hooks |
    Then the output should match:
      | hooks.+#3.+deployed |
    When I run the :get client command with:
      | resource | pod |
    Then the output should match:
      | READY\\s+STATUS |
      | 1/1\\s+Running  |
    When I run the :get client command with:
      | resource      | deploymentConfig |
      | resource_name | hooks |
      | o             | json |
    Then the output should contain:
      | "type": "ConfigChange" |
      | "value": "Plqe5Wev"    |
      | <changed_val1>         |
      | <changed_val2>         |
    Examples:
      | change_scaling_settings | change_strategy | changed_val1  | changed_val2       |
      | :false                  | :false          |               |                    |
      |                         | :false          | "replicas": 1 |                    |
      |                         |                 | "replicas": 1 | "type": "Recreate" |

  # @author xxing@redhat.com
  # @case_id 457716
  Scenario: CLI rollback with one component
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | deploymentConfig |
      | resource_name | hooks |
      | o             | json |
    Then the output should contain:
      | "type": "Recreate"     |
      | "type": "ConfigChange" |
      | "replicas": 1          |
      | "value": "Plqe5Wev"    |
    When I run the :replace client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/updatev1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | deploymentConfig |
      | resource_name | hooks |
      | o             | json |
    Then the output should contain:
      | "type": "Rolling"         |
      | "type": "ImageChange"     |
      | "replicas": 2             |
      | "value": "Plqe5Wevchange" |
    When I run the :rollback client command with:
      | deployment_name         | hooks-1 |
    Then the output should contain:
      | #3 rolled back to hooks-1                                      |
      | Warning: the following images triggers were disabled           |
      | You can re-enable them with: oc deploy hooks --enable-triggers |
    And the pod named "hooks-3-deploy" becomes ready
    Given I wait for the pod named "hooks-3-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | hooks |
    Then the output should match:
      | hooks.*#3.*deployed |
    When I run the :get client command with:
      | resource | pod |
    Then the output should match:
      | READY\\s+STATUS |
      | (Running)?(Pending)?  |
    When I run the :get client command with:
      | resource      | deploymentConfig |
      | resource_name | hooks |
      | o             | json |
    Then the output should contain:
      | "value": "Plqe5Wev"    |
    And the output should not contain:
      | "type": "ConfigChange" |
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | enable_triggers   ||
    Then the output should contain:
      | Enabled image triggers |

  # @author pruan@redhat.com
  # @case_id 483192
  Scenario: oc deploy negative test
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | deploymentConfig |
      | resource_name | hooks            |
      | o             | json             |
    And the output is parsed as JSON
    Then the expression should be true> @result[:parsed]['status']['latestVersion'] == 1
    When I get project deploymentconfig as JSON
    And evaluation of `@result[:parsed]['items'][0]['metadata']['name']` is stored in the :dc_name clipboard
    When I run the :deploy client command with:
      | deployment_config | notreal |
    Then the step should fail
    Then the output should match:
      | Error\\s+.*\\s+"notreal" not found |
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | retry | true |
    Then the step should fail
    And the output should contain:
      | only failed deployments can be retried |
    Given I wait for the pod named "hooks-1-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            |true |
    When I run the :get client command with:
      | resource      | deploymentConfig |
      | resource_name | hooks |
      | o             | json  |
    And the output is parsed as JSON
    Then the expression should be true> @result[:parsed]['status']['latestVersion'] == 2

  # @author pruan@redhat.com
  # @case_id 483173
  Scenario: Negative test for deployment history
    Given I have a project
    When I run the :describe client command with:
      | resource | dc         |
      | name     | no-such-dc |
    Then the step should fail
    And the output should match:
      | Error\\s+.*\\s+"no-such-dc" not found |
    When I run the :describe client command with:
      | resource | dc              |
      | name     | docker-registry |
    Then the step should fail
    And the output should match:
      | Error\\s+.*\\s+"docker-registry" not found |

  # @author pruan@redhat.com
  # @case_id 487644
  Scenario: New depployment will be created once the old one is complete - single deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/sleepv1.json |
    # simulate 'oc edit'
    When I run the :get client command with:
      | resource      | dc |
      | resource_name | hooks |
      | o             | yaml |
    And I save the output to file>hooks.yaml
    And I replace lines in "hooks.yaml":
      | 200 | 10 |
      | latestVersion: 1 | latestVersion: 2 |
    When I run the :replace client command with:
      | f      | hooks.yaml |
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :running
    When I run the :deploy client command with:
      | deployment_config      | hooks |
    Then the step should succeed
    And the output should contain:
      | hooks #2 deployment pending on update |
      | hooks #1 deployment running |
    And I wait until the status of deployment "hooks" becomes :complete
    And I run the :describe client command with:
      | resource | dc |
      | name     | hooks |
    Then the step should succeed
    And the output should match:
      | Latest Version:\\s+2|
      | Deployment\\s+#2\\s+ |
      | Status:\\s+Complete |
      | Deployment #1:   |
      | Status:\\s+Complete |


  # @author pruan@redhat.com
  # @case_id 484483
  Scenario: Deployment succeed when running time is less than ActiveDeadlineSeconds
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    # simulate 'oc edit'
    When the pod named "hooks-1-deploy" becomes ready
    When I run the :get client command with:
      | resource      | pod            |
      | resource_name | hooks-1-deploy |
      | o             | yaml           |
    And I save the output to file>hooks.yaml
   And I replace lines in "hooks.yaml":
      | activeDeadlineSeconds: 21600 | activeDeadlineSeconds: 300 |
    When I run the :replace client command with:
      | f | hooks.yaml |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | hooks |
    Then the step should succeed
    And a pod becomes ready with labels:
      | deployment=hooks-1 |
      | deploymentconfig=hooks |

  # @author pruan@redhat.com
  # @case_id 489263
  Scenario: Can't stop a deployment in Failed status
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/test-stop-failed-deployment.json |
    When the pod named "test-stop-failed-deployment-1-deploy" becomes ready
    When I run the :deploy client command with:
      | deployment_config | test-stop-failed-deployment |
    Then the step should succeed
    And I run the :deploy client command with:
      | deployment_config | test-stop-failed-deployment |
      | cancel            | true                        |
    Then the step should succeed
    And the output should contain:
      | Cancelled deployment #1 |
    When  I run the :describe client command with:
      | resource | dc |
      | name     | test-stop-failed-deployment  |
    Then the step should succeed

    Then the output by order should match:
      | Deployment #1 |
      | Status:\\s+Failed  |
    And I run the :deploy client command with:
      | deployment_config | test-stop-failed-deployment |
      | cancel            | true                        |
    Then the step should succeed
    And the output should contain:
      | No deployments are in progress |
    And I run the :deploy client command with:
      | deployment_config | test-stop-failed-deployment |
    Then the step should succeed
    And the output should match:
      | test-stop-failed-deployment.*#1.*cancelled |

  # @author pruan@redhat.com
  # @case_id 484482
  Scenario: Deployment is automatically stopped when running time is more than ActiveDeadlineSeconds
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/sleepv1.json|
    # simulate 'oc edit'
    When the pod named "hooks-1-deploy" becomes ready
    When I run the :get client command with:
      | resource      | pod            |
      | resource_name | hooks-1-deploy |
      | o             | yaml           |
    And I save the output to file>hooks.yaml
    And I replace lines in "hooks.yaml":
      | activeDeadlineSeconds: 21600 | activeDeadlineSeconds: 2 |
    When I run the :replace client command with:
      | f | hooks.yaml |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | hooks |
    Then the step should succeed
    And the output should match:
      | hooks.*#1.*failed |


  # @author pruan@redhat.com
  # @case_id 489264
  Scenario: Stop a "Pending" deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    And I wait until the status of deployment "hooks" becomes :running
    And I run the :deploy client command with:
      | deployment_config | hooks |
      | cancel            ||
    Then the step should succeed
    And the output should match:
      | [Cc]ancelled deployment #1 |
    And I wait until the status of deployment "hooks" becomes :failed
    And I run the :deploy client command with:
      | deployment_config | hooks |
      | retry | |
    Then the output should match:
      | etried #1 |
    And I run the :describe client command with:
      | resource | dc |
      | name | hook |
    Then the step should succeed
    And I run the :deploy client command with:
      | deployment_config | hooks |
    And I wait until the status of deployment "hooks" becomes :complete

  # @author pruan@redhat.com
  # @case_id 489265
  Scenario: Stop a "Running" deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    And I wait until the status of deployment "hooks" becomes :running
    And I wait up to 60 seconds for the steps to pass:
    """
    And I run the :deploy client command with:
      | deployment_config | hooks |
      | cancel            ||
    Then the step should succeed
    """
    And the output should match:
      | ancelled deployment #1 |
    And I wait until the status of deployment "hooks" becomes :failed
    And I run the :deploy client command with:
      | deployment_config | hooks |
      | retry | |
    Then the output should match:
      | etried #1 |
    And I run the :describe client command with:
      | resource | dc |
      | name | hook |
    Then the step should succeed
    And I run the :deploy client command with:
      | deployment_config | hooks |
    And I wait until the status of deployment "hooks" becomes :complete

  # @author pruan@redhat.com
  # @case_id 490716
  Scenario: Make a new deployment by using a invalid LatestVersion
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    And I wait until the status of deployment "hooks" becomes :complete
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            |true |
    And I wait until the status of deployment "hooks" becomes :complete
    And I replace resource "dc" named "hooks" saving edit to "tmp_out.yaml":
      | latestVersion: 2 | latestVersion: -1 |
    Then the step should fail
    And the output should match:
      | nvalid value.*-1.*latestVersion cannot be negative |
      | nvalid value.*-1.*latestVersion cannot be decremented |
    And I replace resource "dc" named "hooks":
      | latestVersion: 2 | latestVersion: 0 |
    Then the step should fail
    And the output should match:
      | nvalid value.*0.*latestVersion cannot be decremented |
    And I replace resource "dc" named "hooks":
      | latestVersion: 2 | latestVersion: 5 |
    Then the step should fail
    And the output should match:
      | nvalid value.*5.*latestVersion can only be incremented by 1 |

  # @author pruan@redhat.com
  # @case_id 487643
  Scenario: Deployment will be failed if deployer pod no longer exists
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    # deployment 1
    And I wait until the status of deployment "hooks" becomes :complete
    # deployment 2
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            | true  |
    And I wait until the status of deployment "hooks" becomes :complete
    # deployment 3
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            | true  |
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :complete
    Then I run the :describe client command with:
      | resource | dc    |
      | name     | hooks |
    And the output by order should contain:
      | Deployment #3 (latest): |
      |  Status:		Complete      |
      | Deployment #2:          |
      |  Status:		Complete      |
      | Deployment #1:          |
      | Status:		Complete       |
    And I replace resource "rc" named "hooks-2":
      | Complete | Running |
    Then the step should succeed
    And I replace resource "rc" named "hooks-3":
      | Complete | Pending |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            | true  |
    And I wait until the status of deployment "hooks" becomes :complete
    Then I run the :describe client command with:
      | resource | dc    |
      | name     | hooks |
    And the output by order should contain:
      | Deployment #4 (latest): |
      | Status:		Complete       |
      | Deployment #3:          |
      | Status:		Failed         |
      | Deployment #2:          |
      | Status:		Failed         |
      | Deployment #1:          |
      | Status:		Complete       |

  # @author cryan@redhat.com
  # @case_id 497366
  Scenario: Roll back via CLI
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    Given I wait for the pod named "hooks-1-deploy" to die
    When I run the :replace client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/updatev1.json |
    Then the step should succeed
    Given I wait for the pod named "hooks-2-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest ||
    Then the step should succeed
    And the output should contain "Started deployment #3"
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | cancel ||
    Then the step should succeed
    And the output should contain "ancelled deployment #3"
    When I run the :rollback client command with:
      | deployment_name | hooks |
    Then the step should succeed
    And the output should contain "rolled back to hooks-2"
    Given I wait for the pod named "hooks-4-deploy" to die
    When I run the :rollback client command with:
      | deployment_name | hooks |
      | to_version | 1 |
    Then the step should succeed
    And the output should contain "rolled back to hooks-1"
    Given I wait for the pod named "hooks-5-deploy" to die
    When I run the :rollback client command with:
      | deployment_name | dc/hooks |
    Then the step should succeed
    And the output should contain "rolled back to hooks-4"

  # @author pruan@redhat.com
  # @case_id 483190
  Scenario: Make multiple deployment by oc deploy
    Given I have a project
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource | deploymentConfig |
      | resource_name | hooks       |
    Then the output should match:
      |NAME         |
      |hooks.*onfig |
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest ||
    Then the step should fail
    And the output should contain:
      | error |
      | in progress |
    Given I wait for the pod named "hooks-1-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest ||
    Then the step should succeed
    # Given I wait for the pod named "hooks-2-deploy" to die
    When I run the :get client command with:
      | resource | deploymentConfig |
      | resource_name | hooks       |
    Then the step should succeed
    And the output should match:
      |NAME          |
      |hooks.*onfig |
    # This deviate form the testplan a little in that we are not doing more than one deploy, which should be sufficient since we are checking two deployments already (while the testcase called for 5)

  # @author cryan@redhat.com
  # @case_id 489296
  @admin
  Scenario: Check the default option value for command oadm prune deployments
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    Then the step should succeed
    When I run the :new_app client command with:
      | template | ruby-helloworld-sample|
    Then the step should succeed
    Given I wait for the pod named "database-1-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | database |
      | n | <%= project.name %> |
      | latest ||
    Then the step should succeed
    Given I wait for the pod named "database-2-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | database |
      | n | <%= project.name %> |
      | latest ||
    Then the step should succeed
    Given I wait for the pod named "database-3-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | database |
      | n | <%= project.name %> |
      | latest ||
    Then the step should succeed
    Given I wait for the pod named "database-4-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | database |
      | n | <%= project.name %> |
      | latest ||
    Then the step should succeed
    Given I wait for the pod named "database-5-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | database |
      | n | <%= project.name %> |
      | latest ||
    Then the step should succeed
    Given I wait for the pod named "database-6-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | database |
      | n | <%= project.name %> |
      | latest ||
    Then the step should succeed
    Given I wait for the pod named "database-7-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | database |
      | n | <%= project.name %> |
      | latest ||
    Then the step should succeed
    Given I wait for the pod named "database-8-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | database |
      | n | <%= project.name %> |
      | latest ||
    Then the step should succeed
    Given I wait for the pod named "database-9-deploy" to die
    When I run the :deploy client command with:
      | deployment_config | database |
      | n | <%= project.name %> |
      | cancel ||
    Then the step should succeed
    When I run the :get client command with:
      | resource | rc |
      | n | <%= project.name %> |
    Then the step should succeed
    And the output should contain:
      | database-1 |
      | database-9 |
    When I run the :oadm_prune_deployments client command with:
      |h||
    Then the step should succeed
    And the output should contain "completed and failed deployments"
    Given 60 seconds have passed
    When I run the :oadm_prune_deployments admin command with:
      | keep_younger_than | 1m |
    Then the step should succeed
    And the output should match:
      |NAMESPACE\\s+NAME|
      |<%= project.name %>\\s+database-\\d+|
    When I run the :oadm_prune_deployments admin command with:
      | confirm | false |
    Then the step should succeed
    And the output should not match:
      |<%= project.name %>\\s+database-\\d+|

  # @author xiaocwan@redhat.com
  # @case_id 510221
  Scenario: View the logs of the latest deployment
    # check deploy log when deploying
    Given I have a project
    When I run the :run client command with:
      |  name  | hooks   |
      | image  | <%= project_docker_repo %>openshift/hello-openshift:latest|
    Then the step should succeed
    Given the pod named "hooks-1-deploy" becomes ready
    When I run the :logs client command with:
      | resource_name | dc/hooks |
    Then the output should match:
      | eploying |

    Given I collect the deployment log for pod "hooks-1-deploy" until it disappears
    And I run the :logs client command with:
      | resource_name | dc/hooks |
    Then the step should succeed
    And the output should contain "erving"

    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            |       |
    And I run the :deploy client command with:
      | deployment_config | hooks |
      | cancel            |       |
    Then I wait until the status of deployment "hooks" becomes :failed
    And I run the :logs client command with:
      | resource_name | dc/hooks |
    Then the step should fail
    And the output should contain "not available"
    # check for non-existent dc
    When I run the :logs client command with:
      | resource_name | dc/nonexistent |
    Then the step should fail
    And the output should contain "not found"

  # @author yinzhou@redhat.com
  # @case_id 497540
  Scenario: A/B Deployment
    Given I have a project
    When I run the :new_app client command with:
      | docker_image   | <%= project_docker_repo %>openshift/deployment-example |
      | name         | ab-example-a |
      | l            | ab-example=true |
      | env          | SUBTITLE=shardA |
    Then the step should succeed
    When I run the :expose client command with:
      | resource      | deploymentconfig |
      | resource_name | ab-example-a |
      | name          | ab-example   |
      | selector      | ab-example=true |
    Then the step should succeed
    When I expose the "ab-example" service
    Then I wait for a web server to become available via the "ab-example" route
    And the output should contain "shardA"
    When I run the :new_app client command with:
      | docker_image   | <%= project_docker_repo %>openshift/deployment-example |
      | name         | ab-example-b |
      | l            | ab-example=true |
      | env          | SUBTITLE=shardB |
    Then the step should succeed
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | ab-example-a     |
      | replicas | 0                |
    Given I wait until number of replicas match "0" for replicationController "ab-example-a-1"
    When I use the "ab-example" service
    Then I wait for a web server to become available via the "ab-example" route
    And the output should contain "shardB"
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | ab-example-b     |
      | replicas | 0                |
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | ab-example-a     |
      | replicas | 1                |
    Given I wait until number of replicas match "0" for replicationController "ab-example-b-1"
    When I use the "ab-example" service
    Then I wait for a web server to become available via the "ab-example" route
    And the output should contain "shardA"

  # @author yinzhou@redhat.com
  # @case_id 497543
  Scenario: Blue-Green Deployment
    Given I have a project
    When I run the :new_app client command with:
      | docker_image   | <%= project_docker_repo %>openshift/deployment-example:v1 |
      | name         | bluegreen-example-old |
    Then the step should succeed
    When I run the :new_app client command with:
      | docker_image   | <%= project_docker_repo %>openshift/deployment-example:v2 |
      | name         | bluegreen-example-new |
    Then the step should succeed
    #When I expose the "bluegreen-example-old" service
    When I run the :expose client command with:
      | resource | svc |
      | resource_name | bluegreen-example-old |
      | name     | bluegreen-example |
    Then the step should succeed
    #And I wait for a web server to become available via the route
    When I use the "bluegreen-example-old" service
    And I wait for a web server to become available via the "bluegreen-example" route
    And the output should contain "v1"
    And I replace resource "route" named "bluegreen-example":
      | name: bluegreen-example-old | name: bluegreen-example-new |
    Then the step should succeed
    When I use the "bluegreen-example-new" service
    And I wait for the steps to pass:
    """
    And I wait for a web server to become available via the "bluegreen-example" route
    And the output should contain "v2"
    """

  # @author pruan@redhat.com
  # @case_id 483191
  Scenario: Manually start deployment by oc deploy
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :complete
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should match:
      | hooks.*onfig |
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest ||
    Then the step should succeed
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
    Then the output should match:
      | hooks.*onfig |

  # @author yinzhou@redhat.com
  # @case_id 483179,510608
  Scenario: Pre and post deployment hooks
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/testhook.json |
    Then the step should succeed
    When the pod named "hooks-1-hook-pre" becomes ready
    And I run the :get client command with:
      | resource | pod |
      | resource_name | hooks-1-hook-pre    |
      | output        | yaml        |
    And the output should match:
      | mountPath:\\s+/var/lib/origin |
      | emptyDir:\\s+{} |
      | name:\\s+dataem |
    When the pod named "hooks-1-hook-post" becomes ready
    And I run the :get client command with:
      | resource | pod |
      | resource_name | hooks-1-hook-post    |
      | output        | yaml        |
    And the output should match:
      | mountPath:\\s+/var/lib/origin |
      | emptyDir:\\s+{} |
      | name:\\s+dataem |

  # @author pruan@redhat.com
  # @case_id 483177, 483178
  Scenario Outline: Failure handler of pre-post deployment hook
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/<file_name>|
    Then the step should succeed
    When the pod named "<pod_name>" is present
    And I wait for the steps to pass:

    """
      When I run the :get client command with:
        | resource | pod  |
        | resource_name | <pod_name> |
        |  o        | json |
      And the output is parsed as JSON
      Then the expression should be true> @result[:parsed]['status']['containerStatuses'][0]['restartCount'] > 1
    """
    Examples:
      | file_name | pod_name |
      | pre.json  | hooks-1-hook-pre |
      | post.json | hooks-1-hook-post |

  # @author cryan@redhat.com
  # @case_id 515805
  Scenario: Could edit the deployer pod during deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc515805/tc515805.json |
    Then the step should succeed
    Given the pod named "database-1-deploy" becomes ready
    When I replace resource "pod" named "database-1-deploy":
      | activeDeadlineSeconds: 21600 | activeDeadlineSeconds: 55 |
    Then the step should succeed
    Given the pod named "database-1-deploy" status becomes :failed
    When I get project pods
    Then the output should contain "DeadlineExceeded"

  # @author yinzhou@redhat.com
  # @case_id 510606
  Scenario: deployment hook volume inheritance that volume name was null
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/tc510606/hooks-null-volume.json |
    Then the step should fail
    And the output should contain "must not be empty"


  # @author yinzhou@redhat.com
  # @case_id 510607
  Scenario: deployment hook volume inheritance -- that volume names which are not found
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/tc510607/hooks-unexist-volume.json |
    Then the step should succeed
    Given I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource | pods |
    Then the output should contain:
      | NAME           |
      | hooks-1-hook-pre|
    """

  # @author yadu@redhat.com
  # @case_id 497544
  Scenario: Recreate deployment strategy
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/deployment/recreate-example.yaml |
    Then the step should succeed
    And I wait until the status of deployment "recreate-example" becomes :complete
    When I use the "recreate-example" service
    And I wait for a web server to become available via the "recreate-example" route
    Then the output should contain:
      | v1 |
    When I run the :tag client command with:
      | source | recreate-example:v2     |
      | dest   | recreate-example:latest |
    Then the step should succeed
    And I wait until the status of deployment "recreate-example" becomes :complete
    When I use the "recreate-example" service
    And I wait for a web server to become available via the "recreate-example" route
    Then the output should contain:
      | v2 |

  # @author pruan@redhat.com
  # @case_id 515920
  Scenario: start deployment when the latest deployment is completed
    Given I have a project
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :complete
    And I replace resource "dc" named "hooks" saving edit to "tmp_out.yaml":
      | replicas: 1 | replicas: 3 |
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :complete
    And I run the :get client command with:
      | resource | rc |
      | o | json |
    And the output is parsed as JSON
    Then the expression should be true> @result[:parsed]['items'][0]['status']['replicas'] == 3

  # @author pruan@redhat.com
  # @case_id 515921
  Scenario: Manual scale dc will update the deploymentconfig's replicas
    Given I have a project
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | dc    |
      | name     | hooks |
      | replicas | 10    |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | dc    |
      | resource_name | hooks |
      | o             | json  |
    And the output is parsed as JSON
    Then the expression should be true> @result[:parsed]['spec']['replicas'] == 10

    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest            ||
    And I wait until number of replicas match "10" for replicationController "hooks-1"
#      And 10 pods become ready with labels:
#        |name=mysql|
    Then I run the :scale client command with:
      | resource | dc    |
      | name     | hooks |
      | replicas | 5     |
    And I wait until number of replicas match "5" for replicationController "hooks-1"


  # @author pruan@redhat.com
  # @case_id 510686
  Scenario: Inline deployer hook logs
    Given I have a project
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/testhook.json |
    And I run the :logs client command with:
      | f | true |
      | resource_name | dc/hooks |
    Then the output should contain:
      | Created lifecycle pod <%= project.name %>/hooks-1-hook-pre for deployment <%= project.name %>/hooks-1 |
      | Finished reading logs for hook pod <%= project.name %>/hooks-1-hook-pre |
      | Created lifecycle pod <%= project.name %>/hooks-1-hook-post for deployment <%= project.name %>/hooks-1 |
      | Finished reading logs for hook pod <%= project.name %>/hooks-1-hook-post |

  # @author yinzhou@redhat.com
  # @case_id 433309
  Scenario: Trigger info is retained for deployment caused by image changes
    Given I have a project
    When I process and create "https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json"
    Then the step should succeed
    Given the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completed
    Given I wait until the status of deployment "frontend" becomes :complete
    When I run the :get client command with:
      | resource      | dc |
      | resource_name | frontend |
      | o             | yaml |
    Then the output by order should match:
      | causes:         |
      | - imageTrigger: |
      | from: |
      | type: ImageChange |

  # @author yinzhou@redhat.com
  # @case_id 433308
  Scenario: Trigger info is retained for deployment caused by config changes
    Given I have a project
    When I run the :new_app client command with:
      | docker_image   | <%= project_docker_repo %>openshift/deployment-example |
    Then the step should succeed
    And I wait until the status of deployment "deployment-example" becomes :complete
    And I replace resource "dc" named "deployment-example":
      | terminationGracePeriodSeconds: 30 | terminationGracePeriodSeconds: 36 |
    Then the step should succeed
    And I wait until the status of deployment "deployment-example" becomes :complete
    When I run the :get client command with:
      | resource      | dc |
      | resource_name | deployment-example |
      | o             | yaml |
    Then the output by order should match:
      | terminationGracePeriodSeconds: 36 |
      | causes:         |
      | - type: ConfigChange |

  # @author yinzhou@redhat.com
  # @case_id 515919
  Scenario: Start new deployment when deployment running
    Given I have a project
    When I run the :new_app client command with:
      | docker_image   | <%= project_docker_repo %>openshift/deployment-example |
    Then the step should succeed
    Given I wait until the status of deployment "deployment-example" becomes :running
    And I replace resource "dc" named "deployment-example":
      | latestVersion: 1 | latestVersion: 2 |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | deployment-example |
    Then the output should match "cancelled.*newer.*running"

  # @author yinzhou@redhat.com
  # @case_id 518647
  Scenario: Check the deployments in a completed state on test deployment configs
    Given I have a project
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/test-deployment.json |
    Then the step should succeed
    And I run the :logs client command with:
      | f | true |
      | resource_name | dc/hooks |
    Then the output should contain:
      | Scaling <%= project.name %>/hooks-1 to 1 before performing acceptance check |
      | Deployment hooks-1 successfully made active |
    And I wait until the status of deployment "hooks" becomes :complete
    When I run the :get client command with:
      | resource      | rc |
      | resource_name | hooks-1 |
      | o             | yaml |
    Then the output by order should match:
      | phase: Complete |
      | status: |
      | replicas: 0 |

  # @author yinzhou@redhat.com
  # @case_id 518648
  Scenario: Check the deployments in a failed state on test deployment configs
    Given I have a project
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/test-deployment.json |
    Then the step should succeed
    Given I wait until the status of deployment "hooks" becomes :running
    And I replace resource "pod" named "hooks-1-deploy":
      | activeDeadlineSeconds: 21600 | activeDeadlineSeconds: 3 |
    Then the step should succeed
    When I run the :deploy client command with:
      | deployment_config | hooks |
    Then the step should succeed
    And the output should match:
      | hooks.*#1.*failed |
    When I run the :get client command with:
      | resource      | rc |
      | resource_name | hooks-1 |
      | o             | yaml |
    Then the output by order should match:
      | phase: Failed |
      | status: |
      | replicas: 0 |

  # @author pruan@redhat.com
  # @case_id 518650
  Scenario: Scale the deployments will failed on test deployment config
    Given I have a project
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/tc518650/test.json |
    Then the step should succeed
    Given I wait until the status of deployment "hooks" becomes :complete
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | hooks            |
      | replicas | 2                |
    Then the step should succeed
    Given I wait until the status of deployment "hooks" becomes :complete
    And I wait until number of replicas match "0" for replicationController "hooks"

    # @author yinzhou@redhat.com
    # @case_id 515919
    Scenario: Start new deployment when deployment running
      Given I have a project
      When I run the :create client command with:
        | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/testhook.json |
      Then the step should succeed
      Given I wait until the status of deployment "hooks" becomes :running
      And I replace resource "dc" named "hooks":
        | latestVersion: 1 | latestVersion: 2 |
      Then the step should succeed
      When I run the :deploy client command with:
        | deployment_config | hooks |
      Then the output should contain "newer deployment was found running"

  # @author cryan@redhat.com
  # @case_id 515922
  Scenario: When the latest deployment failed auto rollback to the active deployment
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Given a pod becomes ready with labels:
    | deployment=hooks-1 |
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | hooks            |
      | replicas | 4                |
    Given I wait until number of replicas match "4" for replicationController "hooks"
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | hooks            |
      | replicas | 2                |
    Given I wait until number of replicas match "2" for replicationController "hooks"
    When I run the :deploy client command with:
      | deployment_config | hooks |
      | latest | true |
    Then the step should succeed
    Given the pod named "hooks-2-deploy" is present
    When I run the :patch client command with:
      | resource      | pod |
      | resource_name | hooks-2-deploy            |
      | p             | {"spec":{"activeDeadlineSeconds": 5}} |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      |dc |
      | resource_name | hooks |
      | p             | {"spec":{"replicas": 4}} |
    Then the step should succeed
    When I run the :get client command with:
      | resource | pod |
      | resource_name | hooks-2-deploy |
      | o | json |
    Then the output should contain ""activeDeadlineSeconds": 5"
    When I run the :get client command with:
      | resource |dc |
      | resource_name | hooks |
      | o | json |
    Then the output should contain ""replicas": 4"
    Given all existing pods die with labels:
      | deployment=hooks-2 |
    When I run the :get client command with:
      | resource | pods |
      | l | deployment=hooks-2 |
    Then the output should not contain "hooks-2"
    Given a pod becomes ready with labels:
      | deployment=hooks-1 |
    When I run the :get client command with:
      | resource | pods |
    And the output should contain:
      | DeadlineExceeded |
      | hooks-1 |

    # @author yinzhou@redhat.com
    # @case_id 481677
    @admin
    Scenario: DeploymentConfig should allow valid value of resource requirements
    Given I have a project
    When I run oc create as admin over ERB URL: https://raw.githubusercontent.com/openshift/origin/master/examples/project-quota/limits.yaml
    Then the step should succeed
    When I run oc create as admin over ERB URL: https://raw.githubusercontent.com/openshift/origin/master/examples/project-quota/quota.yaml
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment-with-resources.json |
      | n | <%= project.name %>  |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | pod    |
      | resource_name | hooks-1-deploy  |
      | o             | yaml   |
    Then the output should match:
      | \\s+limits:\n\\s+cpu: 30m\n\\s+memory: 150Mi\n   |
      | \\s+requests:\n\\s+cpu: 30m\n\\s+memory: 150Mi\n |
    """
    And I wait until the status of deployment "hooks" becomes :complete
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | pod    |
      | o             | yaml   |
    Then the output should match:
      | \\s+limits:\n\\s+cpu: 400m\n\\s+memory: 200Mi\n   |
      | \\s+requests:\n\\s+cpu: 400m\n\\s+memory: 200Mi\n |
    """
