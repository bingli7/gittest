Feature: custombuild.feature

  # @author wzheng@redhat.com
  # @case_id 470349
  Scenario: Build with custom image - origin-custom-docker-builder
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-custombuild.json |
    Then the step should succeed
    And I create a new application with:
      | template | ruby-helloworld-sample |
    Then the step should succeed
    And the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completed
    Given I wait for the pod named "frontend-1-deploy" to die
    Given 2 pods become ready with labels:
      | name=frontend |
    When I run the :get client command with:
      | resource      | service  |
      | resource_name | frontend |
      | o             | json     |
    Then the step should succeed
    And the output is parsed as JSON
    And evaluation of `@result[:parsed]['spec']['clusterIP']` is stored in the :service_ip clipboard
    When I run the :get client command with:
      | resource | pods  |
      | o        | json  |
    Then the step should succeed
    And the output is parsed as JSON
    Given evaluation of `@result[:parsed]['items'][1]['metadata']['name']` is stored in the :pod_name clipboard
    Given I wait up to 120 seconds for the steps to pass:
    """
    When I run the :exec client command with:
      | pod | <%= cb.pod_name %> |
      |oc_opts_end||
      | exec_command | curl |
      | exec_command_arg | <%= cb.service_ip%>:5432 |
    Then the output should contain "Hello from OpenShift v3"
    """
