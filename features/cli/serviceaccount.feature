Feature: ServiceAccount and Policy Managerment

  # @author anli@redhat.com
  # @case_id 490717
  Scenario: Could grant admin permission for the service account username to access to its own project
    Given I have a project
    When I create a new application with:
      | image_stream | ruby         |
      | code         | https://github.com/openshift/ruby-hello-world |
      | name         | myapp         |
    # TODO: anli, this is a work around for AEP, please add step `the step should succeed` according to latest good solution
    Then I wait for the "myapp" service to be created
    Given I create the serviceaccount "demo"
    And I give project admin role to the demo service account
    When I run the :describe client command with:
      | resource | policybindings |
      | name     | :default       |
    Then the output should match:
      | Role:\\s+admin |
      | ServiceAccounts:\\s+demo |
    Then the output should contain:
      | RoleBinding[system:deployers] |
    Given I find a bearer token of the demo service account
    And I switch to the demo service account
    When I run the :get client command with:
      | resource | dc        |
    Then the output should contain:
      | myapp   |

  # @author xxing@redhat.com
  # @case_id 490722
  Scenario: The default service account could only get access to imagestreams in its own project
    Given I have a project
    When I run the :policy_who_can client command with:
      | verb     | get |
      | resource | imagestreams/layers |
    Then the output should match:
      | system:serviceaccounts?:<%= Regexp.escape(project.name) %> |
    When I run the :policy_who_can client command with:
      | verb     | get |
      | resource | pods/layers |
    Then the output should not contain:
      | system:serviceaccounts:<%= Regexp.escape(project.name) %>        |
      | system:serviceaccount:<%= Regexp.escape(project.name) %>:default |
    Given I create a new project
    When I run the :policy_who_can client command with:
      | verb     | get |
      | resource | imagestreams/layers |
    Then the output should not match:
      | system:serviceaccounts?:<%= Regexp.escape(@projects[0].name) %>  |
    When I run the :policy_who_can client command with:
      | verb     | update |
      | resource | imagestreams/layers |
    Then the output should not contain:
      | system:serviceaccounts:<%= Regexp.escape(project.name) %> |
      | system:serviceaccount:<%= Regexp.escape(project.name) %>:default |
    When I run the :policy_who_can client command with:
      | verb     | delete |
      | resource | imagestreams/layers |
    Then the output should not contain:
      | system:serviceaccounts:<%= Regexp.escape(project.name) %> |
      | system:serviceaccount:<%= Regexp.escape(project.name) %>:default |

  # @author xxia@redhat.com
  # @case_id 497381
  Scenario: Could grant view permission for the service account username to access to its own project
    Given I have a project
    When I create a new application with:
      | docker image | <%= project_docker_repo %>openshift/hello-openshift |
      | name         | myapp         |
    # `oc new-app` with just image but no code (such as https://github.com/openshift/ruby-hello-world.git. See oc new-app -h) creates no bc.
    # Thus could be used for AEP along with `the step should succeed`
    Then the step should succeed
    Then I wait for the "myapp" service to be created
    When I give project view role to the default service account
    And I run the :get client command with:
      | resource       | rolebinding  |
      | resource_name  | view         |
    Then the output should match:
      | view.+default         |

    Given I find a bearer token of the default service account
    And I switch to the default service account
    When I run the :get client command with:
      | resource | dc                  |
      | n        | <%= project.name %> |
    Then the step should succeed
    And the output should contain:
      | myapp   |
    When I create a new application with:
      | docker image | <%= project_docker_repo %>openshift/hello-openshift |
      | name         | another-app         |
      | n            | <%= project.name %> |
    Then the step should fail
    When I run the :delete client command with:
      | object_type       | dc        |
      | all               |           |
      | n                 | <%= project.name %> |
    Then the step should fail
    When I give project admin role to the deployer service account
    Then the step should fail

  # @author anli@redhat.com
  # @case_id 497373
  Scenario: Could grant edit permission for the service account group to access to other project
    Given an 8 characters random string of type :dns is stored into the :project1 clipboard
    Given an 8 characters random string of type :dns is stored into the :project2 clipboard
    When I run the :new_project client command with:
      | project_name | <%= cb.project1 %> |
    Then the step should succeed
    When I run the :new_project client command with:
      | project_name | <%= cb.project2 %> |
    Then the step should succeed
    When I run the :policy_add_role_to_group client command with:
      | role | edit     |
      | group_name | system:serviceaccounts:<%= cb.project1 %> |
    Then the step should succeed
    Given I use the "<%= cb.project1 %>" project
    Given I find a bearer token of the system:serviceaccount:<%= cb.project1 %>:default service account
    Given I switch to the system:serviceaccount:<%= cb.project1 %>:default service account
    Given I use the "<%= cb.project2 %>" project
    When I create a new application with:
      | image_stream | ruby         |
      | code         | https://github.com/openshift/ruby-hello-world |
      | name         | myapp         |
    # TODO: anli, this is a work around for AEP, please add step `the step should succeed` according to latest good solution
    Then I wait for the "myapp" service to be created
    When I run the :delete client command with:
      | object_type       | service    |
      | object_name_or_id | myapp  |
      | cascade           | true  |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role  | edit     |
      | user_name |  <%= user(1, switch: false).name %> |
    Then the step should fail
    When I run the :policy_remove_role_from_user client command with:
      | role  | edit     |
      | user_name |  %= user(0, switch: false).name %> |
    Then the step should fail

  # @author anli@redhat.com
  # @case_id 497374
  Scenario: Could grant view permission for the service account group to access to other project
    Given an 8 characters random string of type :dns is stored into the :project1 clipboard
    Given an 8 characters random string of type :dns is stored into the :project2 clipboard
    When I run the :new_project client command with:
      | project_name | <%= cb.project1 %> |
    Then the step should succeed
    When I run the :new_project client command with:
      | project_name | <%= cb.project2 %> |
    Then the step should succeed
    When I create a new application with:
      | image_stream | ruby         |
      | code         | https://github.com/openshift/ruby-hello-world |
      | name         | myapp         |
    # TODO: anli, this is a work around for AEP, please add step `the step should succeed` according to latest good solution
    Then the output should contain:
      | service "myapp" created |
    When I run the :policy_add_role_to_group client command with:
      | role | view     |
      | group_name | system:serviceaccounts:<%= cb.project1 %> |
    Then the step should succeed
    Given I use the "<%= cb.project1 %>" project
    Given I find a bearer token of the system:serviceaccount:<%= cb.project1 %>:default service account
    Given I switch to the system:serviceaccount:<%= cb.project1 %>:default service account
    Given I use the "<%= cb.project2 %>" project
    When I run the :get client command with:
      | resource | service |
    Then the step should succeed
    When I create a new application with:
      | image_stream | ruby         |
      | code         | https://github.com/openshift/ruby-hello-world |
      | name         | myapp2         |
    Then the step should fail
    When I run the :delete client command with:
      | object_type       | service    |
      | object_name_or_id | myapp  |
      | cascade           | true  |
    Then the step should fail
    When I run the :policy_add_role_to_user client command with:
      | role  | edit     |
      | user_name |  <%= user(1, switch: false).name %> |
    Then the step should fail
    When I run the :policy_remove_role_from_user client command with:
      | role  | edit     |
      | user_name |  %= user(0, switch: false).name %> |
    Then the step should fail

  # @author anli@redhat.com
  # @case_id 497375
  Scenario: Could grant edit permission for the service account group to access to its own project
    Given I have a project
    When I create a new application with:
      | image_stream | ruby         |
      | code         | https://github.com/openshift/ruby-hello-world |
      | name         | myapp         |
    # TODO: anli, this is a work around for AEP, please add step `the step should succeed` according to latest good solution
    Then I wait for the "myapp" service to be created
    Given I create the serviceaccount "test1"
    When I run the :policy_add_role_to_group client command with:
      | role | edit     |
      | group_name | system:serviceaccounts:<%= project.name %> |
    Then the step should succeed
    Given I find a bearer token of the system:serviceaccount:<%= project.name %>:test1 service account
    Given I switch to the system:serviceaccount:<%= project.name %>:test1 service account
    And I use the "<%= project.name %>" project
    When I create a new application with:
      | image_stream | ruby         |
      | code         | https://github.com/openshift/ruby-hello-world |
      | name         | myapp2         |
    # TODO: anli, this is a work around for AEP, please add step `the step should succeed` according to latest good solution
    Then I wait for the "myapp2" service to be created
    When I run the :get client command with:
      | resource | service |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type       | service    |
      | object_name_or_id | myapp  |
      | cascade           | true  |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role  | edit     |
      | user_name |  <%= user(1, switch: false).name %> |
    Then the step should fail
    When I run the :policy_remove_role_from_user client command with:
      | role  | edit     |
      | user_name |  %= user(0, switch: false).name %> |
    Then the step should fail

  # @author anli@redhat.com
  # @case_id 497376
  Scenario: Could grant view permission for the service account group to access to its own project
    Given I have a project
    When I create a new application with:
      | image_stream | ruby         |
      | code         | https://github.com/openshift/ruby-hello-world |
      | name         | myapp         |
    # TODO: anli, , this is a work around for AEP, please add step `the step should succeed` according to latest good solution
    Then I wait for the "myapp" service to be created
    Given I create the serviceaccount "test1"
    When I run the :policy_add_role_to_group client command with:
      | role | view     |
      | group_name | system:serviceaccounts:<%= project.name %> |
    Then the step should succeed
    Given I find a bearer token of the system:serviceaccount:<%= project.name %>:test1 service account
    Given I switch to the system:serviceaccount:<%= project.name %>:test1 service account
    And I use the "<%= project.name %>" project
    When I create a new application with:
      | image_stream | ruby         |
      | code         | https://github.com/openshift/ruby-hello-world |
      | name         | myapp2         |
    Then the step should fail
    When I run the :get client command with:
      | resource | service |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type       | service    |
      | object_name_or_id | myapp  |
      | cascade           | true  |
    Then the step should fail
    When I run the :policy_add_role_to_user client command with:
      | role  | edit     |
      | user_name |  <%= user(1, switch: false).name %> |
    Then the step should fail
    When I run the :policy_remove_role_from_user client command with:
      | role  | edit     |
      | user_name |  %= user(0, switch: false).name %> |
    Then the step should fail

  # @author anli@redhat.com
  # @case_id 497377
  Scenario: Could grant edit permission for the service account username to access to other project
    Given an 8 characters random string of type :dns is stored into the :project1 clipboard
    Given an 8 characters random string of type :dns is stored into the :project2 clipboard
    When I run the :new_project client command with:
      | project_name | <%= cb.project1 %> |
    Then the step should succeed
    Given I use the "<%= cb.project1 %>" project
    And I create the serviceaccount "test1"
    When I run the :new_project client command with:
      | project_name | <%= cb.project2 %> |
    Then the step should succeed
    Given I use the "<%= cb.project2 %>" project
    When I run the :policy_add_role_to_user client command with:
      | role       | edit            |
      | user_name | system:serviceaccount:<%= cb.project1 %>:test1 |
    Then the step should succeed

    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    And I run the :new_app client command with:
      | template | ruby-helloworld-sample|
    # TODO: anli, , this is a work around for AEP, please add step `the step should succeed` according to latest good solution
    Then I wait for the "database" service to be created
    Given I use the "<%= cb.project1 %>" project
    Given I find a bearer token of the system:serviceaccount:<%= cb.project1 %>:test1 service account
    Given I switch to the system:serviceaccount:<%= cb.project1 %>:test1 service account
    When I run the :get client command with:
      | resource | pod |
    Then the step should succeed
    Given I use the "<%= cb.project2 %>" project
    When I run the :deploy client command with:
      | deployment_config | database |
      | cancel             ||
    Then the step should succeed
    And the output should contain "ancelled deployment"

    When I run the :policy_add_role_to_user client command with:
      | role  | edit     |
      | user_name |  <%= user(1, switch: false).name %> |
    Then the step should fail
    When I run the :policy_remove_role_from_user client command with:
      | role  | edit     |
      | user_name |  %= user(0, switch: false).name %> |
    Then the step should fail

  # @author anli@redhat.com
  # @case_id 497378
  Scenario: Could grant view permission for the service account username to access to other project
    Given an 8 characters random string of type :dns is stored into the :project1 clipboard
    Given an 8 characters random string of type :dns is stored into the :project2 clipboard
    When I run the :new_project client command with:
      | project_name | <%= cb.project1 %> |
    Then the step should succeed
    Given I use the "<%= cb.project1 %>" project
    And I create the serviceaccount "test1"
    When I run the :new_project client command with:
      | project_name | <%= cb.project2 %> |
    Then the step should succeed
    Given I use the "<%= cb.project2 %>" project
    When I run the :policy_add_role_to_user client command with:
      | role       | view            |
      | user_name | system:serviceaccount:<%= cb.project1 %>:test1 |
    Then the step should succeed

    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    And I run the :new_app client command with:
      | template | ruby-helloworld-sample|
    # TODO: anli, this is a work around for AEP, please add step `the step should succeed` according to latest good solution
    Then I wait for the "database" service to be created
    Given I use the "<%= cb.project1 %>" project
    Given I find a bearer token of the system:serviceaccount:<%= cb.project1 %>:test1 service account
    Given I switch to the system:serviceaccount:<%= cb.project1 %>:test1 service account
    And I use the "<%= project.name %>" project
    When I run the :get client command with:
      | resource | pod |
    Then the step should succeed
    Given I use the "<%= cb.project2 %>" project
    When I run the :deploy client command with:
      | deployment_config | database |
      | cancel             ||
    Then the step should fail
    And the output should contain:
      | ser "system:serviceaccount:<%= cb.project1 %>:test1" cannot update |

    When I run the :policy_add_role_to_user client command with:
      | role  | view     |
      | user_name |  <%= user(1, switch: false).name %> |
    Then the step should fail
    When I run the :policy_remove_role_from_user client command with:
      | role  | view     |
      | user_name |  %= user(0, switch: false).name %> |
    Then the step should fail

  # @author anli@redhat.com
  # @case_id 497380
  Scenario: Could grant edit permission for the service account username to access to its own project
    Given I have a project
    Given I create the serviceaccount "test1"
    When I run the :policy_add_role_to_user client command with:
      | role | edit     |
      | user_name | system:serviceaccount:<%= project.name %>:test1 |
    Then the step should succeed
    Given I find a bearer token of the system:serviceaccount:<%= project.name %>:test1 service account
    Given I switch to the system:serviceaccount:<%= project.name %>:test1 service account
    And I use the "<%= project.name %>" project
    When I create a new application with:
      | image_stream | ruby         |
      | code         | https://github.com/openshift/ruby-hello-world |
      | name         | myapp         |
    # TODO: anli, this is a work around for AEP, please add step `the step should succeed` according to latest good solution
    Then I wait for the "myapp" service to be created
    When I replace resource "dc" named "myapp" saving edit to "tmp_out.yaml":
      | replicas: 1 | replicas: 2 |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type       | pod    |
      | l                 | deploymentconfig=myapp  |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role  | edit     |
      | user_name |  <%= user(1, switch: false).name %> |
    Then the step should fail
    When I run the :policy_remove_role_from_user client command with:
      | role  | edit     |
      | user_name |  %= user(0, switch: false).name %> |
    Then the step should fail

  # @author xiaocwan@redhat.com
  # @case_id 491400
  Scenario: [origin_platformexp_407] Create pods without ImagePullSecrets will inherit the ImagePullSecrets from its service account.
    Given I have a project
    And I create the serviceaccount "myserviceaccount<%= project.name  %>"
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/a8c3f83d3aedfe6930d1b9f56b1e6e8fa42dcd89/pods/hello-pod.json"
    And I replace lines in "hello-pod.json":
      | "serviceAccount": "" | "serviceAccount": "myserviceaccount<%= project.name  %>" |
    Then the step should succeed
    When I run the :create client command with:
      | f                    |  hello-pod.json                      |
    Then the step should succeed

    When I run the :get client command with:
      | resource             |   pods                               |
      | o                    |   yaml                               |
    Then the step should succeed
    And the output should match:
      | imagePullSecrets:\\s+- name: myserviceaccount<%= project.name  %>-dockercfg     |

  # @author xiaocwan@redhat.com
  # @case_id 490720
  Scenario: Could grant admin permission for the service account group to access to other project
    Given an 8 characters random string of type :dns is stored into the :project1 clipboard
    And an 8 characters random string of type :dns is stored into the :project2 clipboard
    When I run the :new_project client command with:
      | project_name | <%= cb.project1 %> |
    Then the step should succeed
    When I run the :new_project client command with:
      | project_name | <%= cb.project2 %> |
    Then the step should succeed
    When I run the :policy_add_role_to_group client command with:
      | role | admin     |
      | group_name | system:serviceaccounts:<%= cb.project1 %> |
    Then the step should succeed
    Given I use the "<%= cb.project1 %>" project
    And I find a bearer token of the system:serviceaccount:<%= cb.project1 %>:default service account
    And I switch to the system:serviceaccount:<%= cb.project1 %>:default service account
    And I use the "<%= cb.project2 %>" project

    When I run the :get client command with:
      | resource | service |
    Then the output should not contain "ruby-hello-world"
    When I create a new application with:
      | image_stream | ruby          |
      | code         | https://github.com/openshift/ruby-hello-world |
      | name         | myapp<%= cb.project1 %>                       |
    Then the step should succeed
    Given I wait for the "myapp<%= cb.project1 %>" service to be created
    When I run the :delete client command with:
      | object_type       | service        |
      | object_name_or_id | myapp<%= cb.project1 %>          |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role      | edit     |
      | user_name |  <%= user(1, switch: false).name %> |
    Then the step should succeed
    When I run the :policy_remove_role_from_user client command with:
      | role      | edit     |
      | user_name |  %= user(0, switch: false).name %> |
    Then the step should succeed

  # @author xiaocwan@redhat.com
  # @case_id 490718
  Scenario: Could grant admin permission for the service account username to access to its own project
    Given an 8 characters random string of type :dns is stored into the :project1 clipboard
    Given an 8 characters random string of type :dns is stored into the :project2 clipboard
    When I run the :new_project client command with:
      | project_name | <%= cb.project1 %> |
    And I run the :new_project client command with:
      | project_name | <%= cb.project2 %> |
    Then the step should succeed
    When I run the :new_app client command with:
      | docker_image | openshift/hello-openshift |
    Then the step should succeed

    When I run the :policy_add_role_to_user client command with:
      | role     | admin                                  |
      | user_name | system:serviceaccount:<%= cb.project1 %>:default |
    Then the step should succeed

    Given I use the "<%= cb.project1 %>" project
    Given I find a bearer token of the system:serviceaccount:<%= cb.project1 %>:default service account
    Given I switch to the system:serviceaccount:<%= cb.project1 %>:default service account
    Given I use the "<%= cb.project2 %>" project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployments_nobc_cpulimit.json |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role      | admin                                  |
      | user_name | <%= user(1, switch: false).name %> |
    Then the step should succeed
    When I run the :policy_remove_role_from_user client command with:
      | role      | admin                                  |
      | user_name | <%= user(1, switch: false).name %> |
    Then the step should succeed
    # pod will be here a little late, so delay this step to the end of case
    When I get project pods
    Then the output should contain:
      | hello-openshift |

  # @author xxia@redhat.com
  # @case_id 511007
  Scenario: Inside one pod, the user of oc operations is the service account that runs the pod
    Given I have a project
    When I run the :run client command with:
      | name      | mydc                 |
      | image     | <%= project_docker_repo %>openshift/origin             |
      | env       | POD_NAMESPACE=<%= project.name %>     |
      | command   | true                 |
      | cmd       | sleep                |
      | cmd       | 3600                 |
    Then the step should succeed

    When I run the :policy_add_role_to_user client command with:
      | role          | view             |
      | user_name     | system:serviceaccount:<%= project.name %>:default  |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=mydc-1    |
    When I execute on the pod:
      | oc  | whoami |
    Then the step should succeed
    And the output should contain "system:serviceaccount:<%= project.name %>:default"
    When I execute on the pod:
      | oc  | get | pod |
    Then the step should succeed
    And the output should contain "mydc"

  # @author xiaocwan@redhat.com
  # @case_id 490719
  Scenario: Could grant admin permission for the service account group to access to its own project
    Given I have a project
    When I run the :new_app client command with:
      | docker_image | openshift/hello-openshift |
    Then the step should succeed
    When I run the :policy_add_role_to_group client command with:
      | role       | admin                                     |
      | group_name | system:serviceaccounts:<%= project.name %> |
    Then the step should succeed
    Given I find a bearer token of the system:serviceaccount:<%= project.name %>:default service account
    Given I switch to the system:serviceaccount:<%= project.name %>:default service account

    When I get project services
    Then the output should contain:
      | hello-openshift |
    ## this template is to create an application without any build
    When I process and create "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployments_nobc_cpulimit.json"
    Then the step should succeed
    When I run the :delete client command with:
      | object_type       | svc             |
      | object_name_or_id | hello-openshift |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role      | admin                                  |
      | user_name | <%= user(1, switch: false).name %> |
    Then the step should succeed
    When I run the :policy_remove_role_from_user client command with:
      | role      | admin                                  |
      | user_name | <%= user(1, switch: false).name %> |
    Then the step should succeed

  # @author xxia@redhat.com
  # @case_id 483278
  Scenario: Check the serviceaccount that runs pod
    Given I have a project
    When I run the :create client command with:
      | f    | https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json |
    Then the step should succeed

    Given the pod named "hello-openshift" becomes ready
    When I run the :get client command with:
      | resource      | pod                |
      | resource_name | hello-openshift    |
      | output        | yaml               |
    Then the step should succeed
    And the output should contain:
      | serviceAccountName: default |
      | secretName: default-token   |

    Given a "sa.yaml" file is created with the following lines:
    """
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: myserviceaccount
    """
    When I run the :create client command with:
      | f    | sa.yaml |
    Then the step should succeed

    Given a "pod.yaml" file is created with the following lines:
    """
    apiVersion: v1
    kind: Pod
    metadata:
      name: hello-openshift-2nd
    spec:
      containers:
      - image: openshift/hello-openshift
        name: hello-openshift
      serviceAccountName: myserviceaccount
    """

    When I run the :create client command with:
      | f    | pod.yaml |
    Then the step should succeed

    Given the pod named "hello-openshift-2nd" becomes ready
    When I run the :get client command with:
      | resource      | pod                |
      | resource_name | hello-openshift-2nd|
      | output        | yaml               |
    Then the step should succeed
    And the output should contain:
      | serviceAccountName: myserviceaccount |
      | secretName: myserviceaccount-token   |

  # @author xiacowan@redhat.com
  # @case_id 483279
  Scenario: Check project service accounts and API tokens associated with the accounts
    Given I have a project
    When I get project sa
    Then the output should contain:
      | default  |
      | builder  |
      | deployer |
    When I get project secret
    Then the output should contain:
      | default-token-  |
      | builder-token-  |
      | deployer-token- |
    When I run the :describe client command with:
      | resource | secret |
      | name     | <%= "default-token-"+@result[:response].split("default-token-")[1].split(" ")[0] %> |
    Then the output should match:
      | token:\\s+\w+ |
    When I get project secret
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret |
      | name     | <%= "builder-token-"+@result[:response].split("builder-token-")[1].split(" ")[0] %> |
    Then the output should match:
      | token:\\s+\w+ |
    When I get project secret
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret |
      | name     | <%= "deployer-token-"+@result[:response].split("deployer-token-")[1].split(" ")[0] %> |
    Then the output should match:
      | token:\\s+\w+ |

  # @author wjiang@redhat.com
  # @case_id 520589
  Scenario: User can get the serviceaccount token via client
    Given I have a project
    When I run the :serviceaccounts_get_token client command with:
      |serviceaccount_name| default|
    Then the step should succeed
    And the output should contain:
      |eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9|
      |eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOi|
    When I run the :serviceaccounts_get_token client command with:
      |serviceaccount_name|builder|
    Then the step should succeed
    And the output should contain:
      |eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9|
      |eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOi|
    When I run the :serviceaccounts_get_token client command with:
      |serviceaccount_name| deployer|
    Then the step should succeed
    And the output should contain:
      |eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9|
      |eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOi|
    Given an 8 characters random string of type :dns is stored into the :serviceaccount_name clipboard
    When I run the :create_serviceaccount client command with:
      |serviceaccount_name|<%= cb.serviceaccount_name %>|
    Then the step should succeed
    When I run the :serviceaccounts_get_token client command with:
      |serviceaccount_name|<%= cb.serviceaccount_name %>|
    Then the step should succeed
    And the output should contain:
      |eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9|
      |eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOi|

  # @author wjiang@redhat.com
  # @case_id 520588
  Scenario: User can generate new token for specific serviceaccount via client
    Given I have a project
    When I run the :serviceaccounts_new_token client command with:
      |serviceaccount_name|default|
    Then the step should succeed
    And the output should contain:
      |eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9|
      |eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOi|
    When I run the :get client command with:
      |resource|users/~|
      |token   |<%= @result[:response] %>|
    Then the step should succeed
    Then the output should contain:
      |system:serviceaccount:<%= project.name %>:default|
    When I run the :serviceaccounts_new_token client command with:
      |serviceaccount_name|builder|
    Then the step should succeed
    And the output should contain:
      |eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9|
      |eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOi|
    When I run the :get client command with:
      |resource|users/~|
      |token   |<%= @result[:response] %>|
    Then the step should succeed
    Then the output should contain:
      |system:serviceaccount:<%= project.name %>:builder|
    When I run the :serviceaccounts_new_token client command with:
      |serviceaccount_name|deployer|
    Then the step should succeed
    And the output should contain:
      |eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9|
      |eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOi|
    When I run the :get client command with:
      |resource|users/~|
      |token   |<%= @result[:response] %>|
    Then the step should succeed
    Then the output should contain:
      |system:serviceaccount:<%= project.name %>:deployer|
    Given an 8 characters random string of type :dns is stored into the :serviceaccount_name clipboard
    When I run the :create_serviceaccount client command with:
      |serviceaccount_name|<%= cb.serviceaccount_name %>|
    Then the step should succeed
    When I run the :serviceaccounts_new_token client command with:
      |serviceaccount_name|<%= cb.serviceaccount_name %>|
    Then the step should succeed
    And the output should contain:
      |eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9|
      |eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOi|
    When I run the :get client command with:
      |resource|users/~|
      |token   |<%= @result[:response] %>|
    Then the step should succeed
    Then the output should contain:
      |system:serviceaccount:<%= project.name %>:<%= cb.serviceaccount_name %>|

