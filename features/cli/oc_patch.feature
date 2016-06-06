Feature: oc patch related scenarios
  # @author xxia@redhat.com
  # @case_id 507672
  Scenario: oc patch can update one or more fields of rescource
    Given I have a project
    And I run the :run client command with:
      | name      | hello             |
      | image     | <%= project_docker_repo %>openshift/hello-openshift |
    Then the step should succeed
    Given I wait until the status of deployment "hello" becomes :running
    When I run the :patch client command with:
      | resource      | dc              |
      | resource_name | hello           |
      | p             | {"spec":{"replicas":2}} |
    Then the step should succeed
    Then I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | dc                 |
      | resource_name | hello              |
      | template      | {{.spec.replicas}} |
    Then the step should succeed
    And the output should contain "2"
    """
    When I run the :patch client command with:
      | resource      | dc              |
      | resource_name | hello           |
      | p             | {"metadata":{"labels":{"template":"newtemp","name1":"value1"}},"spec":{"replicas":3}} |
    Then the step should succeed
    Then I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | dc                 |
      | resource_name | hello              |
      | template      | {{.metadata.labels.template}} {{.metadata.labels.name1}} {{.spec.replicas}} |
    Then the step should succeed
    And the output should contain "newtemp value1 3"
    """

  # @author xxia@redhat.com
  # @case_id 507674
  Scenario: oc patch to update resource fields using JSON format
    Given I have a project
    And I create a new application with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    Then the step should succeed
    Given I wait until the status of deployment "database" becomes :running
    When I run the :patch client command with:
      | resource      | dc              |
      | resource_name | database        |
      | p             | {"spec":{"strategy":{"resources":{"limits":{"memory":"300Mi"}}}}} |
    Then the step should succeed
    Then I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | dc                 |
      | resource_name | database           |
      | template      | {{.spec.strategy.resources.limits.memory}} |
    Then the step should succeed
    And the output should contain "300Mi"
    """

    When I run the :patch client command with:
      | resource      | bc                      |
      | resource_name | ruby-sample-build       |
      | p             | {"spec":{"output":{"to":{"name":"origin-ruby-sample:tag1"}}}} |
    Then the step should succeed
    Then I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | bc                 |
      | resource_name | ruby-sample-build  |
      | template      | {{.spec.output.to.name}} |
    Then the step should succeed
    And the output should contain "origin-ruby-sample:tag1"
    """

    When I run the :patch client command with:
      | resource      | is                      |
      | resource_name | origin-ruby-sample      |
      | p             | {"spec":{"dockerImageRepository":"xxia/origin-ruby-sample"}} |
    Then the step should succeed
    Then I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | is                 |
      | resource_name | origin-ruby-sample |
      | template      | {{.spec.dockerImageRepository}} |
    Then the step should succeed
    And the output should contain "xxia/origin-ruby-sample"
    """

  # @author xxia@redhat.com
  # @case_id 507685
  Scenario: oc patch cannot update non-existing fields and resources
    Given I have a project
    And I run the :run client command with:
      | name      | hello             |
      | image     | <%= project_docker_repo %>openshift/hello-openshift |
    Then the step should succeed
    Given I wait until the status of deployment "hello" becomes :running
    When I run the :patch client command with:
      | resource      | dc              |
      | resource_name | hello           |
      | p             | {"nothisfield":{"replicas":2}} |
    And I run the :get client command with:
      | resource      | dc                 |
      | resource_name | hello              |
      | template      | {{.nothisfield}} |
    Then the step should succeed
    And the output should contain "no value"

    When I run the :patch client command with:
      | resource      | pod             |
      | resource_name | no-this-pod     |
      | p             | {"metadata":{"labels":{"template":"temp1"}} |
    Then the step should fail
    And the output should contain "not found"

  # @author xxia@redhat.com
  # @case_id 507671
  Scenario: oc patch to update resource fields using YAML format
    Given I have a project
    And I create a new application with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    Then the step should succeed
    Given I wait until the status of deployment "database" becomes :running
    When I run the :patch client command with:
      | resource      | dc                   |
      | resource_name | database             |
      | p             | spec:\n  strategy:\n    resources:\n      limits:\n        memory: 300Mi |
    Then the step should succeed
    Then I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | dc                 |
      | resource_name | database           |
      | template      | {{.spec.strategy.resources.limits.memory}} |
    Then the step should succeed
    And the output should contain "300Mi"
    """

    When I run the :patch client command with:
      | resource      | bc                   |
      | resource_name | ruby-sample-build    |
      | p             | spec:\n  output:\n    to:\n      name: origin-ruby-sample:tag1 |
    Then the step should succeed
    Then I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | bc                 |
      | resource_name | ruby-sample-build  |
      | template      | {{.spec.output.to.name}} |
    Then the step should succeed
    And the output should contain "origin-ruby-sample:tag1"
    """

    When I run the :patch client command with:
      | resource      | is                   |
      | resource_name | origin-ruby-sample   |
      | p             | spec:\n  dockerImageRepository: xxia/origin-ruby-sample |
    Then the step should succeed
    Then I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | is                 |
      | resource_name | origin-ruby-sample |
      | template      | {{.spec.dockerImageRepository}} |
    Then the step should succeed
    And the output should contain "xxia/origin-ruby-sample"
    """
