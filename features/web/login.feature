Feature: login related scenario

  # @author wjiang@redhat.com
  # @case_id 473847
  Scenario: login and logout via web
    Given I login via web console
    Given I run the :logout web console action
    Then the step should succeed
    When I perform the :access_overview_page_after_logout web console action with:
      | project_name | <%= rand_str(2, :dns) %> |
    Then the step should succeed

  # @author xiaocwan@redhat.com
  # @case_id 476030
  Scenario: [origin_platformexp_397] The page should not redirect to login page when access /oauth/authorize?client_id=openshift-challenging-client

    Given I login via web console
    When I access the "/oauth/authorize?response_type=token&client_id=openshift-challenging-client" path in the web console
    And I get the html of the web page
    Then the output should contain:
      | A non-empty X-CSRF-Token header is required to receive basic-auth challenges |