Feature:policy related features on web console

  # @author xiaocwan@redhat.com
  # @case_id 476296
  Scenario: All the users in the deleted project should be removed
    Given I have a project
    When I run the :policy_add_role_to_user client command with:
      | role            | edit                               |
      | user name       | <%= user(1, switch: false).name %> |
      | n               | <%= project.name %>                |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role            | view                               |
      | user name       | <%= user(2, switch: false).name %> |
      | n               | <%= project.name %>                |
    Then the step should succeed

    When I switch to the second user
    And I run the :get client command with:
      | resource | project  |
    Then the step should succeed
    And the output should contain:
      | <%= project.name %> |
    When I switch to the third user
    And I run the :get client command with:
      | resource | project  |
    Then the step should succeed
    And the output should contain:
      | <%= project.name %> |

    Given I switch to the first user
    When I perform the :check_specific_project web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    Given I switch to the second user
    When I perform the :check_specific_project web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed
    Given I switch to the third user
    When I perform the :check_specific_project web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed

    Given I switch to the first user
    And the project is deleted
    When I run the :get client command with:
      | resource | project  |
    Then the step should succeed
    And the output should not contain:
      | <%= project.name %> |
    When I switch to the second user
    And I run the :get client command with:
      | resource | project  |
    Then the step should succeed
    And the output should not contain:
      | <%= project.name %> |
    When I switch to the third user
    And I run the :get client command with:
      | resource | project  |
    Then the step should succeed
    And the output should not contain:
      | <%= project.name %> |
