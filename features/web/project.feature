Feature: projects related features via web

  # @author xxing@redhat.com
  # @case_id 479613
  Scenario: Create a project with a valid project name on web console
    When I perform the :new_project web console action with:
      | project_name | <%= rand_str(5, :dns) %> |
      | display_name | test                     |
      | description  | test                     |
    Then the step should succeed
    When I perform the :new_project web console action with:
      | project_name | <%= rand_str(63, :dns) %> |
      | display_name | test                      |
      | description  | test                      |
    Then the step should succeed
    When I perform the :new_project web console action with:
      | project_name | <%= rand_str(2, :dns) %> |
      | display_name | :null                    |
      | description  ||
    Then the step should succeed

  # @author xxing@redhat.com
  # @case_id 481744
  Scenario: Create a project with an invalid name on web console
    Given I login via web console
    When I access the "/console/createProject" path in the web console
    Then the step should succeed
    When I get the "disabled" attribute of the "button" web element:
      | type | submit |
    Then the output should contain "true"
    #create the project with a duplicate project name
    Given a 5 characters random string of type :dns is stored into the :proj_name clipboard
    When I perform the :new_project web console action with:
      | project_name | <%= cb.proj_name %> |
      | display_name | :null               |
      | description  ||
    Then the step should succeed
    When I perform the :new_project web console action with:
      | project_name | <%= cb.proj_name %> |
      | display_name | :null               |
      | description  ||
    Then the step should fail
    When I get the html of the web page
    Then the output should contain "This name is already in use. Please choose a different name."
    # Create a project with <2 characters name
    When I perform the :new_project web console action with:
      | project_name | <%= rand_str(1) %> |
      | display_name | :null              |
      | description  ||
    Then the step should fail
    When I get the "disabled" attribute of the "button" web element:
      | type | submit |
    Then the output should contain "true"
    # Create a project with uper-case letters
    When I perform the :new_project web console action with:
      | project_name | ABCDE |
      | display_name | :null |
      | description  ||
    Then the step should fail
    When I get the html of the web page
    Then the output should contain "Project names may only contain lower-case letters, numbers, and dashes. They may not start or end with a dash."
    When I perform the :new_project web console action with:
      | project_name | -<%= rand_str(4,:dns) %> |
      | display_name | :null                    |
      | description  ||
    Then the step should fail
    When I get the html of the web page
    Then the output should contain "Project names may only contain lower-case letters, numbers, and dashes. They may not start or end with a dash."
    When I perform the :new_project web console action with:
      | project_name | <%= rand_str(4,:dns) %>- |
      | display_name | :null                    |
      | description  ||
    Then the step should fail
    When I get the html of the web page
    Then the output should contain "Project names may only contain lower-case letters, numbers, and dashes. They may not start or end with a dash."
    When I perform the :new_project web console action with:
      | project_name | <%= rand_str(4,:dns) %>#% |
      | display_name | :null                     |
      | description  ||
    Then the step should fail
    When I get the html of the web page
    Then the output should contain "Project names may only contain lower-case letters, numbers, and dashes. They may not start or end with a dash."

  # @author xxing@redhat.com
  # @case_id 499989
  Scenario: Could delete project from web console
    When I create a project via web with:
      | display_name | :null |
      | description  ||
    Then the step should succeed
    When I perform the :create_app_from_image web console action with:
      | project_name | <%= project.name %>   |
      | image_name   | php                   |
      | image_tag    | 5.5                   |
      | namespace    | openshift             |
      | app_name     | php-sample            |
      | source_url   | https://github.com/openshift/cakephp-ex.git |
    Then the step should succeed
    Given the "php-sample-1" build was created
    When I perform the :cancel_delete_project web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I get the html of the web page
    Then the output should contain "<%= project.name %>"
    When I perform the :delete_project web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    Given I wait for the resource "project" named "<%= project.name %>" to disappear
    When I run the :check_project_list web console action
    Then the step should fail
    Given I wait for the :new_project web console action to succeed with:
      | project_name | <%= project.name %> |
      | display_name | :null               |
      | description  ||
    When I perform the :check_project_overview_without_resource web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    When I perform the :delete_project web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    Given I wait for the resource "project" named "<%= project.name %>" to disappear
    When I run the :check_project_list web console action
    Then the step should fail
    Given I create a new project
    When I run the :policy_add_role_to_user client command with:
      | role      | edit            |
      | user_name | <%= user(1, switch: false).name %> |
    Then the step should succeed
    And I run the :policy_add_role_to_user client command with:
      | role      | view                |
      | user_name | <%= user(2, switch: false).name %>    |
    Given I switch to the second user
    When I perform the :delete_project web console action with:
      | project_name | <%= project.name %> |
    And I get the html of the web page
    Then the output should contain:
      | User "<%= user.name %>" cannot delete projects in project "<%= project.name %>" |
    Given I switch to the third user
    When I perform the :delete_project web console action with:
      | project_name | <%= project.name %> |
    And I get the html of the web page
    Then the output should contain:
      | User "<%= user.name %>" cannot delete projects in project "<%= project.name %>" |

  # @author wsun@redhat.com
  # @case_id 470313
  Scenario: Could list all projects based on the user's authorization on web console
    Given an 8 characters random string of type :dns is stored into the :project1 clipboard
    Given an 8 characters random string of type :dns is stored into the :project2 clipboard
    Given an 8 characters random string of type :dns is stored into the :project3 clipboard
    When I run the :new_project client command with:
      | project_name | <%= cb.project1 %> |
    Then the step should succeed
    When I run the :new_project client command with:
      | project_name | <%= cb.project2 %> |
    Then the step should succeed
    When I run the :new_project client command with:
      | project_name | <%= cb.project3 %> |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role  | view     |
      | user_name | <%= user(1, switch: false).name %> |
      | namespace |  <%= cb.project1 %>  |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role  | view     |
      | user_name | <%= user(1, switch: false).name %> |
      | namespace |  <%= cb.project2 %>  |
    Given I switch to the second user
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.project1 %> |
    Then the step should succeed
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.project2 %> |
    Then the step should succeed
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.project3 %> |
    Then the step should fail
    Given I switch to the first user
    When I run the :policy_remove_role_from_user client command with:
      | role | view |
      | user_name | <%= user(1, switch: false).name %> |
      | namespace |  <%= cb.project2 %>  |
    Then the step should succeed
    Given I switch to the second user
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.project1 %> |
    Then the step should succeed
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.project2 %> |
    Then the step should fail
    When I perform the :check_specific_project web console action with:
      | project_name | <%= cb.project3 %> |
    Then the step should fail

  # @author wsun@redhat.com
  # @case_id 499992
  Scenario: Can edit the project description and display name from web console
    When I create a project via web with:
      | display_name | projecttest |
      | description  | test        |
    Then the step should succeed
    When I perform the :check_general_information web console action with:
      | project_name | <%= project.name %> |
      | dispaly_name | projecttest         |
      | description  | test                |
    Then the step should succeed
    When I perform the :cancel_edit_general_informantion web console action with:
      | project_name | <%= project.name %> |
      | display_name | projecttestupdate |
      | description  | testupdate        |
    Then the step should succeed
    When I perform the :check_general_information web console action with:
      | project_name | <%= project.name %> |
      | dispaly_name | projecttest         |
      | description  | test                |
    Then the step should succeed
    When I perform the :save_edit_general_informantion web console action with:
      | project_name | <%= project.name %> |
      | display_name | projecttestupdate |
      | description  | testupdate        |
    Then the step should succeed
    When I perform the :check_general_information web console action with:
      | project_name | <%= project.name %> |
      | dispaly_name | projecttestupdate   |
      | description  | testupdate          |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role      | edit                                |
      | user_name |  <%= user(1, switch: false).name %> |
      | n         | <%= project.name %>                 |
    Given I switch to the second user
    When I perform the :save_edit_general_informantion web console action with:
      | project_name | <%= project.name %> |
      | display_name | projecttesteditor   |
      | description  | testeditor          |
    Then the step should succeed
    When I perform the :check_general_information web console action with:
      | project_name | <%= project.name %> |
      | dispaly_name | projecttestupdate   |
      | description  | testupdate          |
    Then the step should succeed

