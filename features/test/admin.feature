Feature: Testing Admin Scenarios
  @admin
  Scenario: simple create project admin scenario
    When I run the :oadm_new_project admin command with:
      | project_name | demo                                             |
      | display name | OpenShift 3 Demo                                 |
      | description  | This is the first demo project with OpenShift v3 |
      | admin        | <%= user.name %>                                 |
    Then the step should succeed
    When I run the :get client command with:
      | resource | projects |
    Then the step should succeed
    And the output should contain:
      | OpenShift 3 Demo |
      | Active |

  @admin
  Scenario: exec in defailt repo pod
    Given I switch to cluster admin pseudo user
    And I use the "default" project
    And a pod becomes ready with labels:
      | docker-registry=default |
    When I execute on the pod:
      | find            |
      | /registry       |
      | -type           |
      | f               |
    Then the step should succeed
    And the output should contain:
      |blobs/sha|

  # @author: yinzhou@redhat.com
  # @case_id: 515060
  @admin
  Scenario: Use options minify/raw/flatten to check the output of kubeconfig setting
    When I run the :oadm_config_view admin command with:
      | flatten | |
    Then the step should succeed
    And the output should not contain:
      | REDACTED |
    When I run the :oadm_config_view admin command with:
      | raw | |
    Then the step should succeed
    And the output should not contain:
      | REDACTED |
    When I run the :oadm_config_view admin command with:
      | minify | |
    Then the step should succeed
    And the output should contain:
      | REDACTED |

  @admin
  Scenario: test registry restoration
    Given default docker-registry deployment config is restored after scenario

