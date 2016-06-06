Feature: change the policy of user/service account

  # @author anli@redhat.com
  # @case_id 479042
  @smoke
  @admin
  Scenario: Add/Remove a global role
    Given the first user is cluster-admin
    Given I have a project
    When I run the :get client command with:
      | resource   | pod     |
      | namespace  | default |
    And the output should contain:
      | READY  |
    And the output should not contain:
      | cannot |
    When I run the :oadm_remove_cluster_role_from_user admin command with:
      | role_name  | cluster-admin    |
      | user_name  | <%= user.name %> |
    Then the step should succeed
    When I run the :get client command with:
      | resource   | pod              |
      | namespace  | default          |
    And the output should contain:
      | cannot list pods in project "default" |

  # @author xxing@redhat.com
  # @case_id 467925
  Scenario: User can view ,add, remove and modify roleBinding via admin role user
    Given I have a project
    When I run the :describe client command with:
      | resource | policyBindings |
      | name     | :default       |
    Then the output should match:
      | Role:\\s+admin              |
      | Users:\\s+<%= @user.name %> |
    When I run the :oadm_add_role_to_user client command with:
      | role_name | admin            |
      | user_name | <%= user(1, switch: false).name %> |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | policyBindings |
      | name     | :default       |
    Then the output should match:
      | Role:\\s+admin                                                  |
      | Users:\\s+<%= @user.name %>, <%= user(1, switch: false).name %> |
    When I run the :oadm_remove_role_from_user client command with:
      | role_name | admin            |
      | user_name | <%= user(1, switch: false).name %> |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | policyBindings |
      | name     | :default       |
    Then the output should match:
      | Role:\\s+admin              |
      | Users:\\s+<%= @user.name %> |

  # @author wyue@redhat.com
  # @case_id 470304
  @admin
  Scenario: Creation of new project roles when allowed by cluster-admin
    ##cluster admin create a project and add another user as admin
    When admin creates a project
    Then the step should succeed
    When I run the :policy_add_role_to_user admin command with:
      | role            |   admin               |
      | user name       |   <%= user.name %>    |
      | n               |   <%= project.name %> |
    Then the step should succeed

    ## switch user to the test project
    When I use the "<%= project.name %>" project
    Then the step should succeed

    ##create role that only could view service
    When I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/projectviewservice.json|
    Then the step should succeed

    ##no policybinding for this role in project
    When I run the :describe client command with:
      | resource | policybindings |
      | name     | :default       |
    Then the output should not contain:
      | viewservices |

    ##admin try to add one user to the project as vs role
    When I run the :oadm_add_role_to_user client command with:
      | role name       |   viewservices    |
      | user name       |   <%= user.name %>    |
      | role namespace  |   <%= project.name %> |
    Then the step should fail
    And the output should contain:
      | not found |

    ## download json filed for role and update the project name
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/policy.json"
    And I replace lines in "policy.json":
      |"namespace": "wsuntest"|"namespace": "<%= project.name %>"|
    Then the step should succeed

    ##cluster admin create a PolicyBinding
    When I run the :create admin command with:
      |f|policy.json|
    Then the step should succeed

    ##create role again after PolicyBinding is created
    When I run the :delete client command with:
      | object type | roles |
      | all |  |
    When I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/projectviewservice.json|
    Then the step should succeed

    ##admin try to add one user to the project as vs role
    When I run the :oadm_add_role_to_user client command with:
      | role name       |   viewservices    |
      | user name       |   <%= user.name %>    |
      | role namespace  |   <%= project.name %> |
    Then the step should succeed

  # @author xxing@redhat.com
  # @case_id 470312
  @admin
  Scenario: Could get projects for new role which has permission to get projects
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/clustergetproject.json |
    Then the step should succeed
    #clean-up clusterrole
    And I register clean-up steps:
      | I run the :delete admin command with: |
      |   ! f ! https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/clustergetproject.json ! |
      | the step should succeed               |
    When admin creates a project
    Then the step should succeed
    When I run the :oadm_add_role_to_user admin command with:
      | role_name      | viewproject      |
      | user_name      | <%= user.name %> |
      | n              | <%= project.name %> |
    Then the step should succeed
    When I run the :get client command with:
      | resource | project |
    Then the output should match:
      | <%= project.name %>.*Active |

  # @author xiaocwan@redhat.com
  # @case_id 470662
  @admin
  Scenario: [origin_platformexp_239] The page should have error notification popup when got error during archiving resources of project from server
    Given admin creates a project

    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/getlistwatch_projNamespace.json"
    And I replace lines in "getlistwatch_projNamespace.json":
      |   vsp          |       <%= project.name %>            |
    Then the step should succeed
    When I run the :create admin command with:
      | f               | getlistwatch_projNamespace.json     |
    Then the step should succeed
    And the output should contain:
      | created |
    And I register clean-up steps:
      | I run the :delete admin command with:                 |
      | ! object_type       !        clusterrole            ! |
      | ! object_name_or_id !   <%= project.name %>         ! |
      | the step should succeed                               |

    Given cluster role "<%= project.name %>" is added to the "first" user
    When I perform the :check_error_list_project_resources web console action with:
      | project_name | <%= project.name%> |
    Then the step should succeed

  # @author xiaocwan@redhat.com
  # @case_id 470308
  @admin
  Scenario: [origin_platformexp_386][origin_platformexp_279]Both global policy bindings and project policy bindings work
    Given I have a project
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/policy.json"
    And I replace lines in "policy.json":
      | wsuntest | <%= project.name %> |
    Then the step should succeed
    And I run the :create admin command with:
      | f        | policy.json         |
    Then the step should succeed
    And the output should contain:
      | policybinding |

    When I switch to the first user
    And I run the :create client command with:
      | f        | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/deleteservices.json |
      | n        | <%= project.name %> |
    Then the step should succeed
    And the output should contain:
      | role |
    When I run the :policy_add_role_to_user admin command with:
      | role      |   view                               |
      | user name |   <%= user(1,switch: false).name %>  |
    Then the step should succeed
    And I register clean-up steps:
      | I run the :policy_remove_role_from_user admin command with: |
      |! role      ! view !          |
      |! user name !  <%= user(1,switch: false).name %>! |
      | the step should succeed                          |

    When I run the :policy_add_role_to_user client command with:
      | role            |   deleteservices                  |
      | user name       | <%= user(1,switch: false).name %> |
      | role_namespace  | <%= project.name %>               |
    Then the step should succeed

    When I switch to the second user
    And I run the :get client command with:
      | resource          | service |
      | n                 | default |
    Then the step should succeed
    When I run the :policy_who_can admin command with:
      | verb                   | delete   |
      | resource               | services |
      | n           | <%= project.name %> |
    Then the output should contain:
      | <%= user(1).name %> |

  # @author xiaocwan@redhat.com
  # @case_id 470309
  @admin
  Scenario: [origin_platformexp_279]Project bindings only work against the intended project
    Given a 5 characters random string of type :dns is stored into the :project_1 clipboard
    When I run the :new_project client command with:
      | project_name | <%= cb.project_1 %> |
    Then the step should succeed

    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/policy.json"
    And I replace lines in "policy.json":
      | wsuntest | <%= cb.project_1 %> |
    Then the step should succeed
    And I run the :create admin command with:
      | f        | policy.json         |
    Then the step should succeed

    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/deleteservices.json"
    And I replace lines in "deleteservices.json":
      | deleteservices | <%= cb.project_1 %>     |
      | "delete"   | "watch","list","get"        |
      | "services" | "resourcegroup:exposedkube" |
    And I run the :create client command with:
      | f        | deleteservices.json |
      | n        | <%= cb.project_1 %> |
    Then the step should succeed
    And the output should contain:
      | role |

    When I run the :policy_add_role_to_user client command with:
      | role            |   <%= cb.project_1 %>             |
      | user name       | <%= user(1,switch: false).name %> |
      | role_namespace  | <%= cb.project_1 %>               |
    Then the step should succeed

    Given a 5 characters random string of type :dns is stored into the :project_2 clipboard
    When I run the :new_project admin command with:
      | project_name | <%= cb.project_2 %> |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role            |   <%= cb.project_2 %>                  |
      | user name       | <%= user(2,switch: false).name %> |
      | role_namespace  | <%= cb.project_2 %>               |
    Then the step should fail

  # @author xiaocwan@redhat.com
  # @case_id 467926
  Scenario: [origin_platformexp_214] User can view, add , modify and delete specific role to/from new added project via admin role user
    Given I have a project
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/policy/projectviewservice.json"
    And I replace lines in "projectviewservice.json":
      | viewservices | deploy                      |
      | "services"   | "resourcegroup:deployments" |
    Then the step should succeed
    When I run the :create client command with:
      | f            | projectviewservice.json     |
    Then the step should succeed
    And the output should contain:
      | created      |
    When I run the :describe client command with:
      | namespace    | <%= project.name %>          |
      | resource     | policy                       |
      | name         | default                      |
    Then the step should succeed
    And the output should contain:
      | resourcegroup:deployments                   |
      | get                                         |
      | list                                        |
      | watch                                       |

    When I delete matching lines from "projectviewservice.json":
      | "get",       |
    Then the step should succeed
    When I run the :replace client command with:
      | f            | projectviewservice.json      |
    Then the step should succeed
    And the output should contain:
      | replaced     |
    When I run the :describe client command with:
      | namespace    | <%= project.name %>          |
      | resource     | policy                       |
      | name         | default                      |
    Then the step should succeed
    And the output should not contain:
      | get          |

    When I run the :delete client command with:
      | object_type       | role                    |
      | object_name_or_id | deploy                  |
    Then the step should succeed
    And the output should contain:
      | deleted          |
    When I run the :describe client command with:
      | namespace    | <%= project.name %>          |
      | resource     | policy                       |
      | name         | default                      |
    Then the step should succeed
    And the output should not contain:
      | list          |
      | watch         |

  # @author xiaocwan@redhat.com
  # @case_id 490721
  @admin
  Scenario: [origin_platformexp_340]The builder service account only has get/update access to image streams in its own project
    Given a 5 characters random string of type :dns is stored into the :proj1 clipboard
    When I run the :new_project client command with:
      | project_name  | <%= cb.proj1 %>      |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-rhel7.json |
    Then the step should succeed
    When I run the :policy_who_can client command with:
      | verb     |  get                        |
      | resource |  imagestreams/layers        |
    Then the step should succeed
    And the output should contain:
      | system:serviceaccount:<%= cb.proj1 %>:builder  |
      | system:serviceaccounts:<%= cb.proj1 %>         |
    When I run the :policy_who_can client command with:
      | verb     |  update                     |
      | resource |  imagestreams/layers        |
    Then the step should succeed
    And the output should contain:
      | system:serviceaccount:<%= cb.proj1 %>:builder  |
    When I create a new project
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-rhel7.json |
    Then the step should succeed
    When I run the :policy_who_can client command with:
      | verb     |  get                        |
      | resource |  imagestreams/layers        |
    Then the step should succeed
    And the output should not contain:
      | system:serviceaccount:<%= cb.proj1 %>:builder  |
      | system:serviceaccounts:<%= cb.proj1 %>         |
    When I run the :policy_who_can client command with:
      | verb     |  update                     |
      | resource |  imagestreams/layers        |
    Then the step should succeed
    And the output should not contain:
      | system:serviceaccount:<%= cb.proj1 %>:builder  |
    When I run the :oadm_policy_who_can admin command with:
      | verb     |  get                        |
      | resource |  imagestreams               |
      | all_namespaces | false                 |
    Then the step should succeed
    And the output should contain:
      | Namespace: default  |
    When I run the :oadm_policy_who_can admin command with:
      | verb     |  get                        |
      | resource |  imagestreams               |
      | all_namespaces | true                  |
    Then the step should succeed
    And the output should contain:
      | Namespace: <all>  |

  # @author anli@redhat.com
  # @case_id 470302
  @admin
  Scenario: Cluster admin could delegate the administration of a project to a project admin
    Given a 5 characters random string of type :dns is stored into the :proj1 clipboard
    When admin creates a project with:
      | project_name | <%= cb.proj1 %> |
      | admin | <%= user.name %> |
    Then the step should succeed
    Given I use the "<%= cb.proj1 %>" project
    When I run the :policy_add_role_to_user client command with:
      | role  | view     |
      | user_name |  <%= user(1, switch: false).name %> |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role  | edit     |
      | user_name |  <%= user(2, switch: false).name %> |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role  | admin     |
      | user_name |  <%= user(1, switch: false).name %> |
    Then the step should succeed
