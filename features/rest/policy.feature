Feature: REST policy related features

  # @author xiaocwan@redhat.com
  # @case_id 476292
  @admin
  Scenario: Project admin/edtor/viewer only could get the project subresources
    Given I have a project
    When I process and create "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/sample-php-rhel7.json"
    Then the output should match:
      | imagestream\\s+"origin-php-sample"\\s+created |

    ## post rest request by api with token
    When I perform the :get_subresources_oapi rest request with:
      | project name     | <%= project.name %> |
      | resource_type    | imagestreams        |
      | resource_name    | origin-php-sample   |
    And the step should fail
    Then the expression should be true> @result[:exitstatus] == 405

    ## make sure user has right for replicationcontrollers/status which does not include DELETE verb
    Given the first user is cluster-admin
    When I perform the :delete_subresources_api rest request with:
      | project name     | <%= project.name %>   |
      | resource_type    |replicationcontrollers |
      | resource_name    | database-1            |
    And the step should fail
    Then the expression should be true> @result[:exitstatus] == 405

  # @author xiaocwan@redhat.com
  # @case_id 467924
  @admin
  Scenario: Check if the given user or group have the privilege via SubjectAccessReview
    When admin creates a project
    Then the step should succeed
    When I run the :oadm_add_role_to_user admin command with:
      | role_name | view                                   |
      | user_name | <%= user.name %>                       |
      | n         | <%= project.name %>                    |
    Then the step should succeed
    ## post rest request for curl new json
    When I perform the :post_role_oapi rest request with:
      | project_name         | <%= project.name %>       |
      | role                 | localsubjectaccessreviews |
      | kind                 | LocalSubjectAccessReview  |
      | api_version          | v1                        |
      | verb                 | create                    |
      | resource             | pods                      |
      | user                 | <%= user.name %>          |
    Then the step should fail
    And the output should match:
      | [Cc]annot create localsubjectaccessreviews |
      | [Ff]orbidden |
    And the expression should be true> @result[:exitstatus] == 403

    When I run the :oadm_add_role_to_user admin command with:
      | role_name | edit                                   |
      | user_name | <%= user(1).name  %>                   |
      | n         | <%= project.name %>                    |
    Then the step should succeed
    When I perform the :post_role_oapi rest request with:
      | project_name         | <%= project.name %>       |
      | role                 | localsubjectaccessreviews |
      | kind                 | LocalSubjectAccessReview  |
      | api_version          | v1                        |
      | verb                 | create                    |
      | resource             | pods                      |
      | user                 | <%= user(1).name  %>      |
    Then the step should fail
    And the output should match:
      | [Cc]annot create localsubjectaccessreviews |
      | [Ff]orbidden |
    And the expression should be true> @result[:exitstatus] == 403

    When I run the :oadm_add_role_to_user admin command with:
      | role_name | admin                                  |
      | user_name | <%= user(2).name  %>                   |
      | n         | <%= project.name %>                    |
    Then the step should succeed
    When I perform the :post_role_oapi rest request with:
      | project_name         | <%= project.name %>       |
      | role                 | localsubjectaccessreviews |
      | kind                 | LocalSubjectAccessReview  |
      | api_version          | v1                        |
      | verb                 | create                    |
      | resource             | pods                      |
      | user                 | <%= user(2).name  %>      |
    Then the step should succeed
