Feature: Check links in Openshift
  # @author yapei@redhat.com
  # @case_id 515807
  Scenario: check doc links in web
    # check documentation link in getting started instructions
    When I run the :check_documentation_link_in_get_started web console action
    Then the step should succeed
    # check Documentation link on /console help
    When I run the :check_documentation_link_in_console_help web console action
    Then the step should succeed
    # check docs link in about page
    When I run the :check_documentation_link_in_about_page web console action
    Then the step should succeed
    # check doc link on next step page
    When I create a new project via web
    Then the step should succeed
    When I perform the :check_documentation_link_in_next_step_page web console action with:
      | project_name | <%= project.name %>   |
      | image_name   | nodejs                |
      | image_tag    | 0.10                  |
      | namespace    | openshift             |
      | app_name     | nodejs-sample         |
      | source_url   | https://github.com/openshift/nodejs-ex |
    Then the step should succeed
    # check doc link about deployment
    When I perform the :check_documentation_link_in_dc_page web console action with:
      | project_name | <%= project.name %>  |
      | dc_name      | nodejs-sample        |
    Then the step should succeed
