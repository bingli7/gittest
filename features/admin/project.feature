Feature: project permissions

  # @author akostadi@redhat.com
  # @case_id 470300
  @admin
  Scenario: Admin could get/edit/delete the project resources
    ## create project without any user admins
    When admin creates a project
    Then the step should succeed
    And I run the :new_app admin command with:
      | docker image | openshift/ruby-20-centos7~https://github.com/openshift/ruby-hello-world |
      | name         | myapp                |
      | n            | <%= project.name %>  |
      | l            | app=app1             |
    Then the step should succeed

    ## add a user as admin of the project
    When I run the :policy_add_role_to_user admin command with:
      | role            |   admin               |
      | user name       |   <%= user.name %>    |
      | n               |   <%= project.name %> |
    Then the step should succeed

    ## switch user to the test project
    When I use the "<%= project.name %>" project
    Then the step should succeed

    ## test the admin user can actually manage the resources
    When I expose the "myapp" service
    Then the step should succeed

    ## test user can see all project resources
    Given I wait for the "myapp" service to become ready

    When I get project pods
    Then the step should succeed
    And the output should contain:
      |myapp-1-build|
    When I get project services
    Then the step should succeed
    And the output should contain:
      |deploymentconfig=myapp|
    When I get project builds
    Then the step should succeed
    And the output should contain:
      |myapp-1|
      |Source|
    When I get project buildConfigs
    Then the step should succeed
    And the output should contain:
      |SOURCE|
      |ruby-hello-world|
    When I get project replicationcontroller
    Then the step should succeed
    And the output should contain:
      |REPLICAS|
      |deploymentconfig=myapp|
    When I get project imagestream
    Then the step should succeed
    And the output should contain:
      |myapp|
      |DOCKER REPO|
    When I get project deploymentconfig
    Then the step should succeed
    And the output should contain:
      |TRIGGERS|
      |ConfigChange|
      |myapp|

    ## clean-up mess
    When I delete all resources by labels:
      | app=app1 |

    ## create another app and check user has full admin rights
    When I create a new application with:
      | docker image | openshift/mysql-55-centos7                              |
      | code         | https://github.com/openshift/ruby-hello-world           |
      | l            | app=hi                                                  |
      | env          | MYSQL_USER=root,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    Then the step should succeed

    # check MySQL pod
    Given a pod becomes ready with labels:
      | deployment=mysql-55-centos7-1 |
    When I execute on the pod:
      | bash                                                  |
      | -c                                                    |
      | mysql -h $HOSTNAME -uroot -ptest -e 'show databases;' |
    Then the step should succeed
    And the output should contain "test"

    # access mysql through the service
    Given I use the "mysql-55-centos7" service
    And I reload the service
    When I execute on the pod:
      | bash                                                           |
      | -c                                                             |
      | mysql -h <%= service.ip %> -uroot -ptest -e 'show databases;'  |
    Then the step should succeed
    And the output should contain "test"

    ## test delete project
    When I delete the project
    Then the step should succeed

  # @author wyue@redhat.com
  # @case_id 470315
  @admin
  Scenario: Only cluster-admin could get namespaces
    ## create a project with non cluster-admin user
    Given I have a project
    Then the step should succeed

    ## get no projects with another user who has no projects
    When I switch to the second user
    And I run the :get client command with:
      | resource | project |
    Then the output should not contain:
      | <%= project.name %> |

    ## can get all project with cluster-admin
    When I run the :get admin command with:
      | resource | project |
    Then the output should contain:
      | <%= project.name %> |
    And the output should contain:
      | default |

  # @author pruan@redhat.com
  # @case_id 481692
  @admin
  Scenario: oadm new-project should fail when invalid node selector is given
    Given a 5 characters random string of type :dns is stored into the :proj_name clipboard
    When I run the :oadm_new_project admin command with:
      | node_selector | env:qa |
      | project_name  | <%= @clipboard[:proj_name] %> |
    Then the step should fail
    And the output should match:
      | nvalid value.*env:qa |
    When I run the :oadm_new_project admin command with:
      | node_selector | env,qa |
      | project_name  | <%= @clipboard[:proj_name] %> |
    Then the step should fail
    And the output should match:
      | nvalid value.*env,qa |
    When I run the :oadm_new_project admin command with:
      | node_selector | env [qa] |
      | project_name  | <%= @clipboard[:proj_name] %> |
    Then the step should fail
    And the output should match:
      | nvalid value.*env \[qa\] |
    When I run the :oadm_new_project admin command with:
      | node_selector | env, |
      | project_name  | <%= @clipboard[:proj_name] %> |
    Then the step should fail
    And the output should match:
      | nvalid value.*env, |

  # @author pruan@redhat.com
  # @case_id 481693
  @admin
  Scenario: Pod creation should fail when pod's node selector conflicts with project node selector
    Given a 5 characters random string of type :dns is stored into the :proj_name clipboard
    Given I register clean-up steps:
      | admin deletes the "<%= @clipboard[:proj_name] %>" project |
      | the step should succeed                         |
    When I run oc create as admin over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/projects/node-selector.json" replacing paths:
      | ["metadata"]["name"] | <%= @clipboard[:proj_name] %>|
      | ["metadata"]["labels"]["name"] | <%= @clipboard[:proj_name] %>|
    Then the step should succeed
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/selector-east.json |
      | n | <%= @clipboard[:proj_name] %> |
    Then the step should fail
    Then the output should contain:
      | pods "east" is forbidden: pod node label selector conflicts with its project node label selector |

  # @author chaoyang@redhat.com
  # @case_id 481696
  @admin
  Scenario: Could not create a project with invalid node-selector
    When I run the :create admin command with:
      |filename| https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/projects/prj_with_invalid_node-selector.json |
    Then the step should fail
    And the output should match:
      | nvalid value.*env,qa |

