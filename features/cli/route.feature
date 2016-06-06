Feature: route related features via cli
  # @author yinzhou@redhat.com
  # @case_id 470733
  Scenario: Create a route without route's name named ---should be failed
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/negative/route_with_nil_routename.json |
    Then the step should fail
    And the output should contain:
      | equired value |
    And the project is deleted
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/negative/route_with_no_routename.json |
    Then the step should fail
    And the output should contain:
      | equired value |

  # @author yinzhou@redhat.com
  # @case_id 470734
  Scenario: Create a route without service named ---should be failed
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/negative/route_with_nil_servicename.json |
    Then the step should fail
    And the output should contain:
      | equired value |
    And the project is deleted
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/negative/route_with_no_servicename.json |
    Then the step should fail
    And the output should contain:
      | equired value |
    And the project is deleted

  # @author yinzhou@redhat.com
  # @case_id 470731
  Scenario: Create a route with invalid host ---should be failed
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/negative/route_with_invaid__host.json |
    Then the step should fail
    And the output should contain:
      | DNS 952 subdomain |
    And the project is deleted

  # @author cryan@redhat.com
  # @case_id 483239
  Scenario: Expose routes from services
    Given I have a project
    When I run the :new_app client command with:
      | code | https://github.com/openshift/sti-perl |
      | l | app=test-perl|
      | context_dir | 5.20/test/sample-test-app/ |
      | name | myapp |
    Then the step should succeed
    And the "myapp-1" build completed
    Given I wait for the "myapp" service to become ready
    When I expose the "myapp" service
    Then the step should succeed
    Given I get project routes
    And the output should contain "app=test-perl"
    When I run the :describe client command with:
      | resource | route |
      | name | myapp |
    Then the step should succeed
    And the output should match "Labels:\s+app=test-perl"
    When I open web server via the "myapp" route
    Then the output should contain "Everything is fine"

  # @author cryan@redhat.com
  # @case_id 470699
  Scenario: Be unable to add an existed alias name for service
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/route_unsecure.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/route_unsecure.json |
    Then the step should fail
    And the output should contain "routes "route" already exists"

  # @author xiuwang@redhat.com
  # @case_id 511843
  Scenario: Handle openshift cluster dns in builder containner when do sti build
    Given I have a project
    When I run the :new_app client command with:
      | app_repo     | https://github.com/openshift/ruby-hello-world.git |
      | image_stream | openshift/ruby |
    Then the step should succeed
    Then the "ruby-hello-world-1" build completed
    Given I wait for the "ruby-hello-world" service to become ready
    When I run the :expose client command with:
      | resource      | svc              |
      | resource name | ruby-hello-world |
    Then the step should succeed
    And evaluation of `route("ruby-hello-world", service("ruby-hello-world")).dns(by: user)` is stored in the :route_host clipboard
    When I run the :new_app client command with:
      | app_repo     | https://github.com/openshift-qe/sti-ruby-test.git |
      | image_stream | openshift/ruby |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type       | builds          |
      | object_name_or_id | sti-ruby-test-1 |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | buildconfig   |
      | resource_name | sti-ruby-test |
      | p | {"spec": {"strategy": {"sourceStrategy": {"env": [{"name": "APP_ROUTE","value": "<%= cb.route_host%>"}]}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | sti-ruby-test|
      | follow | true |
      | wait   | true |
    And the output should contain:
      | Hello from OpenShift v3 |
