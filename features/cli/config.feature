Feature: config related scenarios
  # @author pruan@redhat.com
  # @case_id 470719
  Scenario: Override the specific parameters in config file
    Given I have a project
    When I run the :config_view client command
    And the output is parsed as YAML
    And evaluation of `@result[:parsed]['current-context']` is stored in the :original_context clipboard
    # we need to switch the context back to a valid entry, otherwise, the FW will try to clean up the invalid context created and not clean up properly
    And I register clean-up steps:
    """
    I run the :config_use_context client command with:
      | name | <%= cb.original_context %> |
    """
    When I run the :config_set_cluster client command with:
      | name | local-server          |
      | server           | http://localhost:8080 |
    Then the step should succeed
    When I run the :config_set_context client command with:
      | name | default-context |
      | cluster          | local-server    |
      | user             | myself          |
    Then the step should succeed
    When I run the :config_use_context client command with:
      | name | default-context |
    Then the step should succeed
    When I run the :config_view client command
    Then the output should contain:
      | server: http://localhost:8080 |
      | name: local-server            |
    When I run the :config_set client command with:
      | prop_name  | contexts.default-context.namespace |
      | prop_value | the-right-prefix                   |
    Then the step should succeed
    When I run the :config_set client command with:
      | prop_name  | preferences.colors |
      | prop_value | true               |
    Then the step should succeed
    When I run the :config_view client command
    And the output should contain:
      | namespace: the-right-prefix |
    And the output is parsed as YAML
    Then the expression should be true> @result[:parsed]['preferences']['colors'] == true
    When I run the :config_unset client command with:
      | prop_name | preferences.colors |
    Then the step should succeed
    When I run the :config_unset client command with:
      | prop_name | contexts.default-context |
    Then the step should succeed
    And I run the :config_view client command
    And the output should not contain:
      | colors: |
    And the output should contain:
      | current-context: default-context |

  # @author pruan@redhat.com
  # @case_id 470722
  Scenario: Override the cluster in config file
    Given I have a project
    When I run the :config_set_cluster client command with:
      | name | cow-cluster         |
      | server           | http://cow.org:8080 |
    Then the step should succeed
    And I run the :config_view client command
    And the output should contain:
      | server: http://cow.org:8080 |
    When I run the :config_set_cluster client command with:
      | name | cow-cluster         |
      | server           | http://cownew.org:8080 |
    Then the step should succeed
    And I run the :config_view client command
    And the output should contain:
      |  server: http://cownew.org:8080 |
    And the output should not contain:
      | server: http://cow.org:8080 |

  # @author pruan@redhat.com
  # @case_id 470723
  Scenario: Override the context in config file
    Given I have a project
    When I run the :config_set_cluster client command with:
      | name | horse-cluster         |
      | server           | http://horse.org:8080 |
    Then the step should succeed
    When I run the :config_set_cluster client command with:
      | name | pig-cluster         |
      | server           | http://pig.org:8080 |
    Then the step should succeed
    When I run the :config_set_context client command with:
      | name | context-label1 |
      | cluster          | horse-cluster  |
      | user             | red-user       |
      | namespace        | horse-ns       |
    Then the step should succeed
    When I run the :config_set_context client command with:
      | name | context-label2 |
      | cluster          | pig-cluster    |
      | user             | blue-user      |
      | namespace        | pig-ns         |
    Then the step should succeed
    When I run the :config_view client command
    And the output should contain:
      | user: red-user  |
      | user: blue-user |
    When I run the :config_set_context client command with:
      | name | horse-cluster |
      | cluster          | horse-cluster |
      | user             | green-user    |
    Then the step should succeed
    When I run the :config_view client command
    And the output should contain:
      | user: green-user |
      | user: blue-user  |

  # @author pruan@redhat.com
  # @case_id 470724
  Scenario: Set cluster and check the config file
    When I run the :config_set_cluster client command with:
      | name | horse-cluster         |
      | server           | http://horse.org:8080 |
    Then the step should succeed
    When I run the :config_set_cluster client command with:
      | name | pig-cluster         |
      | server           | http://pig.org:8080 |
    Then the step should succeed
    When I run the :config_set_cluster client command with:
      | name | cow-cluster         |
      | server           | http://cow.org:8080 |
    Then the step should succeed
    And I run the :config_view client command
    Then the output should contain:
      | http://cow.org:8080   |
      | http://horse.org:8080 |
      | http://pig.org:8080 |

  # @author pruan@redhat.com
  # @case_id 470725
  Scenario: set credentials in config file
    Given I have a project
    When I run the :config_set_creds client command with:
      | name | tc470725           |
      | token            | tc470725-token-old |
    Then the step should succeed
    When I run the :config_view client command
    And the output is parsed as YAML
    Then the expression should be true> @result[:parsed]['users'].any? {|t| t['user']['token'].include? 'tc470725-token-old'}
    When I run the :config_set_creds client command with:
      | name | tc470725           |
      | token            | tc470725-token-new |
    Then the step should succeed
    When I run the :config_view client command
    And the output is parsed as YAML
    Then the expression should be true> @result[:parsed]['users'].any? {|t| t['user']['token'].include? 'tc470725-token-new'}
    # make sure we have replaced the old one and not just add the new along with the old
		And the expression should be true> not @result[:parsed]['users'].any? {|t| t['user']['token'].include? 'tc470725-token-old'}

  # @author pruan@redhat.com
  # @case_id 470726
  Scenario: Setup context and switch to use different context
    Given I have a project
    When I run the :config_view client command
    And the output is parsed as YAML
    And evaluation of `@result[:parsed]['current-context']` is stored in the :original_context clipboard
    # we need to switch the context back to a valid entry, otherwise, the FW will try to clean up the invalid context created and not clean up properly
    And I register clean-up steps:
    """
    I run the :config_use_context client command with:
      | name | <%= cb.original_context %> |
    """
    When I run the :config_set_cluster client command with:
      | name | horse-cluster         |
      | server           | http://horse.org:8080 |
    Then the step should succeed
    When I run the :config_set_cluster client command with:
      | name | pig-cluster         |
      | server           | http://pig.org:8080 |
    Then the step should succeed
    When I run the :config_set_context client command with:
      | name | context-label1  |
      | cluster          | horse-cluster   |
      | user             | horse-user      |
      | namespace        | horse-namespace |
    Then the step should succeed
    When I run the :config_set_context client command with:
      | name | context-label2 |
      | cluster          | pig-cluster    |
      | user             | pig-user       |
      | namespace        | pig-namespace  |
    Then the step should succeed
    When I run the :config_use_context client command with:
      | name | context-label1 |
    Then the step should succeed
    When I run the :config_view client command
    And the output should contain:
      | current-context: context-label1 |
    When I run the :config_use_context client command with:
      | name | context-label2 |
    Then the step should succeed
    When I run the :config_view client command
    And the output should contain:
      | current-context: context-label2 |

  # @author yanpzhan@redhat.com
  # @note expected to only work with token auth user kubeconfig
  # @case_id 477174
  Scenario: Kubeconfig file can be round-trip used
    Given I have a project
    And I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json|
    Then the step should succeed
    When I run the :config_view client command with:
      |flatten||
      |minify||
    And the output is parsed as YAML
    And I save the output to file> user1.kubeconfig
    And I switch to the second user
    When I run the :get client command with:
      |resource|pod|
      |config|user1.kubeconfig|
    Then the step should succeed
    And the output should contain:
      |hello-openshift|
