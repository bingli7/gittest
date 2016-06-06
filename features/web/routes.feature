Feature: Routes related features on web console
  # @author yanpzhan@redhat.com
  # @case_id 509106
  Scenario: Check Routes page
    Given I login via web console
    Given I have a project

    When I perform the :check_empty_routes_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed

    When I perform the :create_app_from_image web console action with:
      | project_name | <%= project.name %>                        |
      | image_name   | nodejs                                     |
      | image_tag    | 0.10                                       |
      | namespace    | openshift                                  |
      | app_name     | nodejs-sample                              |
      | source_url   | https://github.com/openshift/nodejs-ex.git |
    Then the step should succeed
    Given the "nodejs-sample-1" build was created
    Given the "nodejs-sample-1" build completed
    Given I wait for the "nodejs-sample" service to become ready
    And I wait for a web server to become available via the "nodejs-sample" route
    When I run the :get client command with:
      | resource      | route                 |
      | resource_name | nodejs-sample         |
      | template      | {{.spec.host}} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :patch_yaml clipboard

    When I perform the :check_routes_page web console action with:
      | project_name | <%= project.name %> |
      | route_name   | nodejs-sample       |
    Then the step should succeed

    When I perform the :check_a_route_detail_page web console action with:
      | project_name | <%= project.name %> |
      | route_name   | nodejs-sample       |
      | service_name | nodejs-sample       |
    Then the step should succeed

    When I perform the :access_route_hostname web console action with:
      | project_name | <%= project.name %> |
      | route_name   | nodejs-sample       |
      | service_url | <%= cb.patch_yaml %>|
    Then the step should succeed

  # @author yanpzhan@redhat.com
  # @case_id 511915
  Scenario: Create unsecured route on web console
    When I create a new project via web
    Then the step should succeed

    Given I use the "<%= project.name %>" project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_nothing.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed

    When I perform the :open_create_route_page_from_overview_page web console action with:
      | project_name | <%= project.name%> |
      | service_name | service-unsecure   |
    Then the step should succeed

    When I perform the :create_unsecured_route_from_service_or_overview_page web console action with:
      | route_name | service-unsecure-route |
    Then the step should succeed

    When I perform the :check_routes_page web console action with:
      | project_name | <%= project.name %> |
      | route_name   | service-unsecure    |
    Then the step should succeed

  # @author yapei@redhat.com
  # @case_id 511913
  Scenario: Create route for multi-port services on web console
    When I create a new project
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    Given the pod named "caddy-docker" becomes ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/services/multi-portsvc.json |
    Then the step should succeed
    When I perform the :goto_routes_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :check_empty_routes_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :create_route_dont_specify_hostname_from_routes_page web console action with:
      | service_name | multi-portsvc       |
      | route_name   | myroute1            |
      | target_port  | 443                 |
    Then the step should succeed
    When I perform the :create_route_dont_specify_hostname_from_routes_page web console action with:
      | project_name | <%= project.name %> |
      | service_name | multi-portsvc       |
      | route_name   | myroute2            |
      | target_port  | 80                  |
    Then the step should succeed
    When I perform the :check_route_page_loaded_successfully web console action with:
      | project_name | <%= project.name %> |
      | route_name   | myroute1            |
      | service_name | multi-portsvc       |
    Then the step should succeed
    When I get the html of the web page
    Then the output should match:
      | route to.*27443.*443 |
    When I perform the :check_route_page_loaded_successfully web console action with:
      | project_name | <%= project.name %> |
      | route_name   | myroute2            |
      | service_name | multi-portsvc       |
    Then the step should succeed
    When I get the html of the web page
    Then the output should match:
      | route to.*27017.*80 |
