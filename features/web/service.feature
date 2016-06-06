Feature: services related feature on web console

  # @author wsun@redhat.com
  # @case_id 477695
  Scenario: Access services from web console
    Given I login via web console
    Given I have a project
    # oc process -f file | oc create -f -
    When I process and create "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/tc/tc477695/hello.json"
    Then the step should succeed
    When I perform the :check_service_list_page web console action with:
      | project_name | <%= project.name %> |
      | service_name | hello-service       |
    Then the step should succeed
    When I perform the :check_one_service_page web console action with:
      | project_name | <%= project.name %> |
      | service_name | hello-service       |
      | selectors    | name=hello-pod      |
      | type         | ClusterIP           |
      | routes       | www.hello.com       |
      | target_port  | 5555                |
    Then the step should succeed
    When I replace resource "route" named "hello-route":
      | www.hello.com | www.hello2.com |
    Then the step should succeed
    When I perform the :check_one_service_page web console action with:
      | project_name | <%= project.name %> |
      | service_name | hello-service       |
      | selectors    | name=hello-pod      |
      | type         | ClusterIP           |
      | routes       | www.hello2.com      |
      | target_port  | 5555                |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/tc/tc477695/new_route.json |
      | n | <%= project.name %> |
    Then the step should succeed
    When I perform the :check_one_service_page web console action with:
      | project_name | <%= project.name %> |
      | service_name | hello-service       |
      | selectors    | name=hello-pod      |
      | type         | ClusterIP           |
      | routes       | www.hello1.com      |
      | target_port  | 5555                |
    When I run the :delete client command with:
      | object_type | route             |
      | object_name_or_id | hello-route |
      | n | <%= project.name %> |
    Then the step should succeed
    When I perform the :check_one_service_page web console action with:
      | project_name | <%= project.name %> |
      | service_name | hello-service       |
      | selectors    | name=hello-pod      |
      | type         | ClusterIP           |
      | routes       | none                |
      | target_port  | 5555                |
    When I replace resource "service" named "hello-service":
      | 5555 | 5556 |
    Then the step should succeed
    When I perform the :check_one_service_page web console action with:
      | project_name | <%= project.name %> |
      | service_name | hello-service       |
      | selectors    | name=hello-pod      |
      | type         | ClusterIP           |
      | routes       | none                |
      | target_port  | 5556                |
    When I run the :delete client command with:
      | object_type | service             |
      | object_name_or_id | hello-service |
      | n | <%= project.name %> |
    Then the step should succeed
    When I perform the :check_deleted_service web console action with:
      | project_name    | <%= project.name %> |
      | service_name    | hello-service       |
      | service_warning | The service details could not be loaded |
    Then the step should succeed
