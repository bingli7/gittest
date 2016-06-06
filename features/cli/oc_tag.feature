Feature: oc tag related scenarios

  # @author xxia@redhat.com
  # @case_id 492275 492278 492277 492279 
  Scenario Outline: Tag an image into image stream
    Given I have a project
    When I run the :tag client command with:
      | source_type  | docker                     |
      | source       | docker.io/library/busybox:latest   |
      | dest         | mystream:latest            |
    Then the step should succeed
    # Cucumber runs steps fast. Need wait for the istag so that it really can be referenced by following steps
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | istag             |
      | resource_name | mystream:latest   |
    Then the step should succeed
    """

    When I run the :get client command with:
      | resource      | istag             |
      | resource_name | mystream:latest   |
      | template      | {{.image.metadata.name}}   |
    Then the step should succeed
    And evaluation of `"mystream@" + @result[:response]` is stored in the :src clipboard

    When I run the :tag client command with:
      | source_type  | <source_type>              |
      | source       | <source>                   |
      | dest         | <deststream>:tag           |
      | alias        | true                       |
    Then the step should succeed

    # Same reason as above. Need wait, instead of one-time check
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | istag             |
      | resource_name | <deststream>:tag  |
    Then the step should succeed
    """
    When I run the :get client command with:
      | resource      | is                |
      | resource_name | <deststream>      |
      | o             | yaml              |
    Then the step should succeed
    And the output should contain:
      | from:                             |
      |   kind: <kind>                    |
      |   name: <source>                  |

    # Add case_id to easily find the row for each case
    Examples: Tag into imagestream that does not exist
      | case_id | source_type | source          | deststream | kind             |
      | 492275  | isimage     | <%= cb.src %>   | newstream  | ImageStreamImage |
      | 492278  | istag       | mystream:latest | newstream  | ImageStreamTag   |

    Examples: Tag into imagestream that exists
      | case_id | source_type | source          | deststream | kind             |
      | 492277  | istag       | mystream:latest | mystream   | ImageStreamTag   |
      | 492279  | docker      | docker.io/library/busybox:latest  | mystream   | DockerImage      |

  # @author xxia@redhat.com
  # @case_id 492276
  Scenario: Tag an image into mutliple image streams
    Given I have a project
    When I run the :tag client command with:
      | source_type  | docker                     |
      | source       | docker.io/library/busybox:latest   |
      | dest         | mystream:latest            |
    Then the step should succeed
    # Cucumber runs steps fast. Need wait for the istag so that it really can be referenced by following steps
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | istag             |
      | resource_name | mystream:latest   |
    Then the step should succeed
    """

    When I run the :tag client command with:
      | source_type  | docker                     |
      | source       | docker.io/library/busybox:latest   |
      | dest         | mystream:tag               |
    Then the step should succeed
    # Same reason as above case. Need wait, instead of one-time check
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | is                |
    Then the step should succeed
    And the output should match "mystream.+tag,latest"
    """

    When I create a new project
    Then the step should succeed
    And I create a new project
    Then the step should succeed
    When I run the :tag client command with:
      | source_type  | istag                                 |
      | source       | <%= @projects[0].name %>/mystream:latest |
      | dest         | <%= @projects[0].name %>/mystream:tag1   |
      | dest         | <%= @projects[1].name %>/stream1:tag1  |
      | dest         | <%= @projects[2].name %>/stream2:tag2  |
    Then the step should succeed

    When I run the :get client command with:
      | resource      | is                      |
      | namespace     | <%= @projects[0].name %> |
    Then the step should succeed
    And the output should match "mystream.+tag1,tag,latest"
    When I run the :get client command with:
      | resource      | is                      |
      | namespace     | <%= @projects[2].name %> |
    Then the step should succeed
    And the output should match "stream2.+tag2"

  # @author cryan@redhat.com
  # @case_id 519853
  # @bug_id 1304109
  Scenario: Tag image from another project via oc tag and use it to create app via oc new-app
    Given I have a project
    And evaluation of `project.name` is stored in the :stage clipboard
    When I run the :new_build client command with:
      | app_repo | https://github.com/openshift/ruby-hello-world |
    Then the step should succeed
    Given the "ruby-hello-world-1" build completes
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    Given the "ruby-hello-world-2" build completes
    When I run the :get client command with:
      | resource | istag |
      | resource_name | ruby-hello-world:latest |
      | template | {{.image.metadata.name}} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :img2 clipboard
    When I create a new project
    Then the step should succeed
    And evaluation of `project.name` is stored in the :prod clipboard
    When I run the :tag client command with:
      | source       | <%= cb.stage %>/ruby-hello-world:latest |
      | dest         | <%= cb.prod %>/myis:tag1 |
    Then the step should succeed
    Then the output should match "set to.*<%= cb.img2[0..15] %>"
    Given I use the "<%= cb.prod %>" project
    When I run the :new_app client command with:
      | app_repo | myis:tag1 |
    Then the step should succeed
    Given I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource | pod |
      | l | app=myis |
      | o | yaml |
    Then the output should contain "unauthorized"
    """
    When I run the :policy_add_role_to_user client command with:
      | role | edit |
      | user_name | system:serviceaccount:<%= cb.prod %>:default |
      | n | <%= cb.stage %> |
    Then the step should succeed
    When I run the :new_app client command with:
      | app_repo | myis:tag1 |
      | name | myapp |
      | n | <%= cb.prod %> |
    Then the step should succeed
    Then a pod becomes ready with labels:
      | app=myapp |
