Feature: Pod related features on web console
  # @author yanpzhan@redhat.com
  # @case_id 510378
  Scenario: View streaming logs for a running pod
    When I create a new project via web
    Then the step should succeed
    Given I use the "<%= project.name %>" project

    #Create a pod
    And I run the :run client command with:
      | name         | testpod                   |
      | image        | openshift/hello-openshift |
      | generator    | run-pod/v1                |
      | -l           | rc=mytest                 |

    Given the pod named "testpod" becomes ready

    #Go to the pod page
    When I perform the :goto_one_pod_page web console action with:
      | project_name | <%= project.name %> |
      | pod_name     | testpod             |
    Then the step should succeed

    #Check on log tab
    When I perform the :check_log_tab web console action with:
      | pod_status | Running |
    Then the step should succeed
    #Check log
    When I perform the :check_log_context web console action with:
      | log_context | serving |
    Then the step should succeed
    #View log in new window
    When I perform the :open_full_view_log web console action with:
      | log_context | serving |
    Then the step should succeed

    #Create a pod with 2 containers
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_two_containers.json |
    Then the step should succeed
    Given the pod named "doublecontainers" becomes ready

    When I perform the :goto_one_pod_page web console action with:
      | project_name | <%= project.name %> |
      | pod_name     | doublecontainers    |
    Then the step should succeed

    When I perform the :check_log_tab web console action with:
      | pod_status | Running |
    Then the step should succeed

    #Select one of the containers
    When I perform the :select_a_container web console action with:
      | container_name | hello-openshift-fedora |
    Then the step should succeed

    When I perform the :check_log_context web console action with:
      | log_context | serving |
    Then the step should succeed

    When I perform the :open_full_view_log web console action with:
      | log_context | serving |
    Then the step should succeed

  # @author yapei@redhat.com
  # @case_id 498129
  Scenario: Generate same labels in the UI as CLI
    When I create a project via web with:
      | display_name | :null |
      | description  ||
    Then the step should succeed
    When I perform the :create_app_from_image web console action with:
      | project_name | <%= project.name %>  |
      | image_name   | python               |
      | image_tag    | 3.3                  |
      | namespace    | openshift            |
      | app_name     | python-sample        |
      | source_url   | https://github.com/openshift/django-ex.git |
    Then the step should succeed
    Given I use the "<%= project.name %>" project
    Given I wait for the "python-sample" service to become ready
    When I run the :get client command with:
      | resource      | pod              |
      | resource_name | <%= pod.name %>  |
      | o             | json             |
    Then the step succeeded
    And the output is parsed as JSON
    Given evaluation of `@result[:parsed]['metadata']['labels']` is stored in the :label_from_ui clipboard
    # check labels via cli
    Given I create a new project
    When I run the :new_app client command with:
      | image_stream | python:3.3    |
      | code         | https://github.com/openshift/django-ex.git |
      | name         | python-sample |
    Then the step should succeed
    Given I wait for the "python-sample" service to become ready
    When I run the :get client command with:
      | resource      | pod              |
      | resource_name | <%= pod.name %>  |
      | o             | json             |
    Then the step succeeded
    And the output is parsed as JSON
    Given evaluation of `@result[:parsed]['metadata']['labels']` is stored in the :label_from_cli clipboard
    Then the expression should be true> cb.label_from_ui == cb.label_from_cli
