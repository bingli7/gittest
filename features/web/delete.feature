Feature: Delete the resources via web console

  # @author wsun@redhat.com
  # @case_id 512251
  Scenario: Delete app resources on web console as admin user
    When I create a project via web with:
      | display_name | :null               |
      | description  ||
    Then the step should succeed
    Given I wait for the :create_app_from_image web console action to succeed with:
      | project_name | <%= project.name %>                        |
      | image_name   | nodejs                                     |
      | image_tag    | 0.10                                       |
      | namespace    | openshift                                  |
      | app_name     | nodejs-sample                              |
      | source_url   | https://github.com/openshift/nodejs-ex.git |
    Given I use the "nodejs-sample" service
    Given I wait for the "nodejs-sample" service to become ready
    When I run the :deploy client command with:
      | namespace         | <%= project.name %> |
      | deployment_config | nodejs-sample       |
    Then the step should succeed
    And I wait until the status of deployment "nodejs-sample" becomes :complete
    When I perform the :delete_resources_in_the_project web console action with:
      | project_name     | <%= project.name %>   |
      | pod_name         | nodejs-sample-1-build |
      | service_name     | nodejs-sample         |
      | build_name       | nodejs-sample         |
      | deployment_name  | nodejs-sample         |
      | buildconfig_name | nodejs-sample-1       |
      | route_name       | nodejs-sample         |
      | image_name       | nodejs-sample         |
      | rc_name          | nodejs-sample-1       |
    Then the step should succeed
    When I perform the :check_deleted_resources web console action with:
      | project_name     | <%= project.name %>   |
      | pod_name         | nodejs-sample-1-build |
      | pod_warning      | The pod details could not be loaded. |
      | service_name     | nodejs-sample         |
      | service_warning  | The service details could not be loaded |
      | build_name       | nodejs-sample         |
      | build_warning    | The build configuration details could not be loaded. |
      | deployment_name  | nodejs-sample         |
      | dc_warning       | The deployment configuration details could not be loaded. |
      | buildconfig_name | nodejs-sample-1       |
      | bc_warning       | The build configuration details could not be loaded. |
      | route_name       | nodejs-sample         |
      | route_warning    | The route details could not be loaded. |
      | image_name       | nodejs-sample         |
      | image_warning    | The image stream details could not be loaded. |
      | rc_name          | nodejs-sample-1       |
      | rc_warning       | The deployment details could not be loaded. |

  # @author wsun@redhat.com
  # @case_id 512253
  Scenario: The viewer can not delete app resources on web console
    Given I have a project
    When I create a new application with:
      | image_stream | openshift/nodejs|
      | code         | https://github.com/openshift/nodejs-ex.git |
      | namespace    | <%= project.name %>                        |
      | name         | nodejs-sample                |
    Then the step should succeed
    When I expose the "nodejs-sample" service
    Then the step should succeed
    Given I wait for the "nodejs-sample" service to become ready
    When I run the :policy_add_role_to_user client command with:
      | role      |   view    |
      | user_name | <%= user(1, switch: false).name %> |
    Then the step should succeed
    Given I switch to the second user
    When I perform the :delete_resources_in_the_project web console action with:
      | project_name     | <%= project.name %>   |
      | pod_name         | nodejs-sample-1-build |
      | pod_warning      | The pod details could not be deleted. |
      | service_name     | nodejs-sample         |
      | service_warning  | The service details could not be deleted. |
      | build_name       | nodejs-sample         |
      | build_warning    | The build configuration details could not be deleted. |
      | deployment_name  | nodejs-sample         |
      | dc_warning       | The deployment configuration details could not be deleted. |
      | buildconfig_name | nodejs-sample-1       |
      | bc_warning       | The build configuration details could not be deleted. |
      | route_name       | nodejs-sample         |
      | route_warning    | The route details could not be deleted. |
      | image_name       | nodejs-sample         |
      | image_warning    | The image stream details could not be deleted. |
      | rc_name          | nodejs-sample-1       |
      | rc_warning       | The deployment details could not be deleted. |
    Then the step should succeed
