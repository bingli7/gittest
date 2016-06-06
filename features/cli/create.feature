Feature: creating 'apps' with CLI

  # @author akostadi@redhat.com
  # @case_id 482262
  @smoke
  Scenario: Create an application with overriding app name
    Given I have a project
    And I create a new application with:
      | image_stream | openshift/ruby:latest |
      | code         | https://github.com/openshift/ruby-hello-world |
      | name         | myapp                |
      # | namespace    | <%= project.name %>  |
    Then the step should succeed
    When I expose the "myapp" service
    Then the step should succeed
    And I wait for a web server to become available via the route
    And the project is deleted

    ## recreate project between each test because of
    #    https://bugzilla.redhat.com/show_bug.cgi?id=1233503
    ## create app with broken labels
    # disabled for https://bugzilla.redhat.com/show_bug.cgi?id=1251601
    #Given I have a project
    #When I create a new application with:
    #  | docker image | openshift/ruby-20-centos7~https://github.com/openshift/ruby-hello-world |
    #  | name         | upperCase |
    #Then the step should fail
    #And the project is deleted

    # https://bugzilla.redhat.com/show_bug.cgi?id=1247680
    Given I have a project
    When I create a new application with:
      | image_stream | openshift/ruby~https://github.com/openshift/ruby-hello-world |
      | name         | <%= rand_str(25, :dns952) %> |
    Then the step should fail
    And the project is deleted

    Given I have a project
    When I create a new application with:
      | docker image | <%= product_docker_repo %>rhscl/perl-520-rhel7~https://github.com/openshift/sti-perl |
      | context dir  | 5.16/test/sample-test-app/            |
      | name         | 4igit-first |
      | insecure_registry | true |
    Then the step should fail
    And the project is deleted

    Given I have a project
    When I create a new application with:
      | docker image | <%= product_docker_repo %>rhscl/ruby-22-rhel7~https://github.com/openshift/ruby-hello-world |
      | name         | with#char |
    Then the step should fail
    And the project is deleted

    Given I have a project
    When I create a new application with:
      | image_stream | openshift/perl:5.16~https://github.com/openshift/sti-perl |
      | context dir  | 5.16/test/sample-test-app/            |
      | name         | with^char |
    Then the step should fail
    And the project is deleted

    Given I have a project
    When I create a new application with:
      | image_stream | openshift/ruby~https://github.com/openshift/ruby-hello-world |
      | name         | with@char |
    Then the step should fail
    And the project is deleted

    ## create app with labels
    And I have a project
    When I create a new application with:
      | image_stream | openshift/ruby:latest                                   |
      | image_stream | openshift/mysql:latest                                  |
      | code         | https://github.com/openshift/ruby-hello-world           |
      | l            | app=hi                                                  |
      | env          | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    Then the step should succeed

    # check MySQL pod
    Given a pod becomes ready with labels:
      | deployment=mysql-1 |
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | bash                                                  |
      | -c                                                    |
      | mysql -h $HOSTNAME -utest -ptest -e 'show databases;' |
    Then the step should succeed
    And the output should contain "test"
    """

    # access mysql through the service
    Given I use the "mysql" service
    And I reload the service
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | bash                                                           |
      | -c                                                             |
      | mysql -h <%= service.ip %> -utest -ptest -e 'show databases;'  |
    Then the step should succeed
    And the output should contain "test"
    """

    # access web app through the service
    Given the "ruby-hello-world-1" build was created
    Given the "ruby-hello-world-1" build completed
    Given I wait for the "ruby-hello-world" service to become ready
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | bash                       |
      | -c                         |
      | curl -k <%= service.url %> |
    Then the step should succeed
    And the output should contain "Demo App"
    """

    # delete resources by label
    When I delete all resources by labels:
     | app=hi |
    Then the step should succeed
    And the project should be empty

  # @author xxing@redhat.com
  # @case_id 470351
  Scenario: Create application from template via cli
    Given I have a project
    When I run the :create client command with:
      |f| https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-template-sti.json |
    And I create a new application with:
      |template|ruby-helloworld-sample|
      |param   |MYSQL_USER=admin,MYSQL_PASSWORD=admin,MYSQL_DATABASE=xxingtest|
    Then the step should succeed
    When I expose the "frontend" service
    Then I wait for a web server to become available via the "frontend" route
    And the output should contain "Demo App"
    Given I wait for the "database" service to become ready
    When I execute on the pod:
      | bash |
      | -c   |
      | mysql -h <%= service.ip %> -P5434 -uadmin -padmin -e 'show databases;'|
    Then the step should succeed
    And the output should contain "xxingtest"

  # @author wsun@redhat.com
  # case_id 476293
  Scenario: Could not create any context in non-existent project
    Given I create a new application with:
      | docker image | openshift/ruby-20-centos7~https://github.com/openshift/ruby-hello-world |
      | name         | myapp          |
      | n            | noproject      |
    Then the step should fail
    Then the output should contain "User "<%=@user.name%>" cannot create imagestreams in project "noproject""
    Then the output should contain "User "<%=@user.name%>" cannot create buildconfigs in project "noproject""
    Then the output should contain "User "<%=@user.name%>" cannot create services in project "noproject""
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/hello-pod.json |
      | n | noproject |
    Then the step should fail
    Then the output should contain "User "<%=@user.name%>" cannot create pods in project "noproject""
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
      | n | noproject |
    Then the step should fail
    Then the output should contain "User "<%=@user.name%>" cannot create deploymentconfigs in project "noproject""
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-centos7.json |
      | n | noproject |
    Then the step should fail
    Then the output should contain "Error from server: User "<%=@user.name%>" cannot create imagestreams in project "noproject""
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
      | n | noproject |
    Then the step should fail
    Then the output should contain "User "<%=@user.name%>" cannot create templates in project "noproject""

  # @author anli@redhat.com
  # @case_id 470297
  Scenario: Project admin could not grant cluster-admin permission to other users
    When I have a project
    And I run the :oadm_add_cluster_role_to_user client command with:
      | role_name | cluster-admin  |
      | user_name | <%= user(1).name %>  |
    Then the step should fail
    And the output should contain "cannot get clusterpolicybindings at the cluster scope"

  # @author pruan@redhat.com
  # @case_id 483163
  Scenario: create app from existing template via CLI with parameter passed
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    Then the step should succeed
    And I run the :get client command with:
      | resource | template |
    Then the step should succeed
    And the output should contain:
      | ruby-helloworld-sample   This example shows how to create a simple ruby application in openshift |
    And I run the :new_app client command with:
      | template | ruby-helloworld-sample |
      | param    | MYSQL_DATABASE=db1,ADMIN_PASSWORD=pass1|
    Then the step should succeed
    Given I wait for the "frontend" service to become ready
    And I run the :get client command with:
      | resource | deploymentConfig |
      | resource_name | frontend    |
      | output        | yaml        |
    Then the output by order should match:
      | name: ADMIN_PASSWORD |
      | value: pass1         |
      | name: MYSQL_DATABASE |
      | value: db1           |

  # @author cryan@redhat.com
  # @case_id 476353
  Scenario: Easy delete resources of 'new-app' created
    Given I have a project
    Given a 5 characters random string of type :dns is stored into the :rand_label clipboard
    When I run the :new_app client command with:
      | code | https://github.com/openshift/sti-perl |
      | l | app=<%= cb.rand_label %> |
      | context_dir | 5.20/test/sample-test-app/ |
    Then the step should succeed
    And the "sti-perl-1" build completed
    When I run the :delete client command with:
      | all_no_dash ||
      | l | app=<%= cb.rand_label %> |
    Then the step should succeed
    When I run the :get client command with:
      | resource | all |
    Then the project should be empty
    Given a 5 characters random string of type :dns is stored into the :rand_label2 clipboard
    Given a 5 characters random string of type :dns is stored into the :rand_label3 clipboard
    Given a 5 characters random string of type :dns is stored into the :rand_label4 clipboard
    When I run the :new_app client command with:
      | code | https://github.com/openshift/sti-perl |
      | l | app2=<%= cb.rand_label2 %>,app3=<%= cb.rand_label3 %>,app4=<%= cb.rand_label4 %> |
      | context_dir | 5.20/test/sample-test-app/ |
    Then the step should succeed
    And the "sti-perl-1" build completed
    When I run the :get client command with:
      | resource | all |
      | l | app2=<%= cb.rand_label2 %> |
    Then the step should succeed
    And the output should contain "sti-perl"
    When I run the :delete client command with:
      | all_no_dash ||
      | l | app2=<%= cb.rand_label2 %> |
    Then the step should succeed
    When I run the :get client command with:
      | resource | all |
    Then the project should be empty

  # @author yadu@redhat.com
  # @case_id 510959
  Scenario: Debugging a Service
    Given I have a project
    When I run the :create client command with:
       |f| https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/list_for_pods.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :get client command with:
       | resource | pod |
    Then the step should succeed
    And the output should contain:
       | Running |
    When I run the :get client command with:
       | resource | service |
    Then the step should succeed
    And the output should contain:
       | test-service |
       | name=test-pods |
    When I run the :get client command with:
       | resource | endpoints |
    And the output should contain:
       | test-service |
    Given I wait for the "test-service" service to become ready
    When I execute on the pod:
       |curl|
       |-k|
       |<%= service.url %>|
    Then the step should succeed
    And the output should contain "Hello OpenShift!"

  # @author chunchen@redhat.com
  # @case_id 482263
  Scenario: Create an application from images
    Given I have a project
    When I create a new application with:
      | image_stream | openshift/python|
      | image_stream | openshift/mysql |
      | code         | git://github.com/openshift/sti-python |
      | context_dir  | 3.4/test/standalone-test-app |
      | group        | openshift/python+openshift/mysql |
      | env        | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=ccytest|
    Then the step should succeed
    And the "sti-python-1" build completed
    And a pod becomes ready with labels:
      | deployment=sti-python-1      |
      | deploymentconfig=sti-python  |
    And I wait for the "sti-python" service to become ready
    And I wait for the steps to pass:
    """
    When I run the :exec client command with:
      | pod     | <%= pod.name %> |
      | c     | mysql |
      |oc_opts_end ||
      | exec_command | /opt/rh/rh-mysql56/root/usr/bin/mysql |
      | exec_command_arg |-h<%= service.ip %>|
      | exec_command_arg |-utest|
      | exec_command_arg |-ptest|
      | exec_command_arg |-estatus|
    Then the step should succeed
    And the output should match "Uptime:\s+(\d+\s+min\s+)?\d+\s+sec"
    """
    Given I wait for the "sti-python" service to become ready
    And I wait for the steps to pass:
    """
    When I run the :exec client command with:
      | pod     | <%= pod.name %> |
      | c       | sti-python |
      |oc_opts_end ||
      | exec_command | curl|
      | exec_command_arg |-s|
      | exec_command_arg | <%= service.url %>|
    Then the step should succeed
    """
    When I create a new application with:
      | image_stream | openshift/python |
      | code         | git://github.com/openshift/sti-python |
      | context_dir  | 3.4/test/standalone-test-app |
      | name         | sti-python1 |
    Then the step should succeed
    And the "sti-python1-1" build completed
    When I create a new application with:
      | docker_image | openshift/python-34-centos7 |
      | code         | git://github.com/openshift/sti-python |
      | context_dir  | 3.4/test/standalone-test-app |
      | name         | sti-python2 |
    Then the step should succeed
    And the "sti-python2-1" build completed
    Given I wait for the "sti-python2" service to become ready
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl | -s | <%= service.url %> |
    Then the step should succeed
    """
    Given the project is deleted
    And I have a project
    When I create a new application with:
      | docker_image | openshift/python-34-centos7  |
      | docker_image | openshift/mysql-55-centos7 |
      | code         | git://github.com/openshift/sti-python |
      | context_dir  | 3.4/test/standalone-test-app |
      | group        | openshift/python-34-centos7+openshift/mysql-55-centos7  |
      | env | MYSQL_ROOT_PASSWORD=test|
    Then the step should succeed
    And the "sti-python-1" build completed
    And a pod becomes ready with labels:
      | deployment=sti-python-1      |
      | deploymentconfig=sti-python  |
    And I wait for the "sti-python" service to become ready
    And I wait for the steps to pass:
    """
    When I run the :exec client command with:
      | pod     | <%= pod.name %> |
      | c     | mysql-55-centos7 |
      |oc_opts_end ||
      | exec_command | /opt/rh/mysql55/root/usr/bin/mysql |
      | exec_command_arg |-h<%= service.ip %>|
      | exec_command_arg |-uroot|
      | exec_command_arg |-ptest|
      | exec_command_arg |-estatus|
    Then the step should succeed
    And the output should match "Uptime:\s+(\d+\s+min\s+)?\d+\s+sec"
    """
    Given I wait for the "sti-python" service to become ready
    And I wait for the steps to pass:
    """
    When I run the :exec client command with:
      | pod     | <%= pod.name %> |
      | c       | sti-python |
      |oc_opts_end ||
      | exec_command | curl|
      | exec_command_arg |-s|
      | exec_command_arg | <%= service.url %> |
    Then the step should succeed
    """

  # @author pruan@redhat.com
  # @case_id 476350
  Scenario: Create resources with labels --Negetive test
    Given I have a project
    And I run the :new_app client command with:
      | docker_image | <%= product_docker_repo %>rhscl/ruby-22-rhel7 |
      | labels | name#@=ruby-hello-world |
      | insecure_registry | true |
    Then the step should fail
    And the output should contain:
      | metadata.labels|
      | Invalid value|
      | name#@ |
    And I run the :new_app client command with:
      | docker_image | <%= product_docker_repo %>rhscl/ruby-22-rhel7 |
      | labels | name=@#@ |
      | insecure_registry | true |
    Then the step should fail
    And the output should contain:
      | metadata.labels|
      | Invalid value|
      | @#@ |
    And I run the :new_app client command with:
      | docker_image | <%= product_docker_repo %>rhscl/ruby-22-rhel7 |
      | labels | name=value1,name=value2,name=deadbeef010203 |
      | insecure_registry | true |
    Then the step should succeed
    When I run the :get client command with:
      | resource | all |
      | l | name=deadbeef010203 |
    Then the step should succeed
    And the output should contain:
      | ruby-22-rhel7 |

  # @author xiacwan@redhat.com
  # @case_id 510225
  Scenario: [platformmanagement_public_523]Use the old version v1beta3 file to create resource 
    Given I switch to the first user
    And I have a project
    When I run the :create client command with:
      | f       | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod-with-v1beta3.json |
    Then the step should succeed
    Given the pod named "hello-pod" becomes ready
    When I run the :get client command with:
      | resource | pod |
      | resource_name | hello-pod |
      |  o  | yaml |
    Then the output should contain:
      |  apiVersion: v1  |

  # @author yinzhou@redhat.com
  # @case_id 510547
  Scenario: Progress with invalid supplemental groups should not be run when using RunAsAny as the RunAsGroupStrategy
    Given I have a project
    When I run the :create client command with:
      | f       | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_special_supplementalGroups.json |
    Then the step should fail
    And the output should contain:
      | Pod "hello-openshift" is invalid  |
      | Invalid value                     |
      | must be between 0 and 2147483647  |

  # @author yinzhou@redhat.com
  # @case_id 510545
  Scenario: Process with special supplemental groups can be run when using RunAsAny as the RunAsGroupStrategy
    Given I have a project
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_special_supplementalGroups.json"
    And I replace lines in "pod_with_special_supplementalGroups.json":
      |4294967296|0|
    Then the step should succeed
    When I run the :create client command with:
      | f | pod_with_special_supplementalGroups.json |
    Then the step should succeed
    When the pod named "hello-openshift" becomes ready
    When I run the :get client command with:
      | resource | pod             |
      | resource_name | hello-openshift |
      | output       | yaml        |
    Then the output by order should match:
      | securityContext:|
      | supplementalGroups: |
      | - 0 |

  # @author yinzhou@redhat.com
  # @case_id 510544
  Scenario: Process with special FSGroup id can be ran when using RunAsAny as the RunAsGroupStrategy
    Given I have a project
    When I run the :create client command with:
      | f       | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_special_fsGroup.json |
    Then the step should succeed

    When the pod named "hello-openshift" becomes ready
    When I run the :get client command with:
      | resource | pod             |
      | resource_name | hello-openshift |
      | output       | yaml        |
    Then the output by order should match:
      | securityContext:|
      | fsGroup: 0 |

  # @author cryan@redhat.com
  # @case_id 467937
  Scenario: User can expose the environment variables to pods
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc467937/pod467937.yaml |
    Then the step should succeed
    Given the pod named "kubernetes-metadata-volume-example" becomes ready
    When I execute on the pod:
      | ls | -laR | /etc |
    Then the step should succeed
    And the output should contain:
      | annotations -> |
      | labels -> |

  # @author cryan@redhat.com
  # @case_id 521730
  Scenario: Can add label to app even it exists
    Given I have a project
    #The json file below contains several labels
    #that are specific to this testcase
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/test/fixtures/template-with-app-label.json |
    Then the step should succeed
    When I run the :new_app client command with:
      | app_repo | ruby-helloworld-sample |
    Given the "ruby-sample-build-1" build completes

  # @author cryan@redhat.com
  # @case_id 474050
  Scenario: Create an application from source code
    Given I have a project
    When I git clone the repo "https://github.com/openshift/ruby-hello-world"
    Then the step should succeed
    Given an 8 character random string of type :dns952 is stored into the :appname clipboard
    When I run the :new_app client command with:
      | app_repo | ruby-hello-world |
      | image_stream | openshift/ruby:latest |
      | name | <%= cb.appname %> |
      | env | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    Given the "<%= cb.appname %>-1" build completes
    Given 1 pods become ready with labels:
      | deployment=<%= cb.appname %>-1 |
    When I execute on the "<%= pod.name %>" pod:
      | curl | localhost:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    #Check https github url
    Given an 8 character random string of type :dns952 is stored into the :appname1 clipboard
    When I run the :new_app client command with:
      | code | https://github.com/openshift/ruby-hello-world |
      | image_stream | openshift/ruby:2.2 |
      | name | <%= cb.appname1 %> |
      | env | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    Given the "<%= cb.appname1 %>-1" build completes
    Given 1 pods become ready with labels:
      | deployment=<%= cb.appname1 %>-1 |
    When I execute on the "<%= pod.name %>" pod:
      | curl | localhost:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    #Check http github url
    Given an 8 character random string of type :dns952 is stored into the :appname2 clipboard
    When I run the :new_app client command with:
      | code | http://github.com/openshift/ruby-hello-world |
      | image_stream | openshift/ruby:2.0 |
      | name | <%= cb.appname2 %> |
      | env | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    Given the "<%= cb.appname2 %>-1" build completes
    Given 1 pods become ready with labels:
      | deployment=<%= cb.appname2 %>-1 |
    When I execute on the "<%= pod.name %>" pod:
      | curl | localhost:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    #Check git github url
    Given an 8 character random string of type :dns952 is stored into the :appname3 clipboard
    When I run the :new_app client command with:
      | code | git://github.com/openshift/ruby-hello-world |
      | image_stream | openshift/ruby |
      | name | <%= cb.appname3 %> |
      | env | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    Given the "<%= cb.appname3 %>-1" build completes
    Given 1 pods become ready with labels:
      | deployment=<%= cb.appname3 %>-1 |
    When I execute on the "<%= pod.name %>" pod:
      | curl | localhost:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    #Check master branch
    Given an 8 character random string of type :dns952 is stored into the :appname4 clipboard
    When I run the :new_app client command with:
      | code | https://github.com/openshift/ruby-hello-world#master |
      | image_stream | openshift/ruby |
      | name | <%= cb.appname4 %> |
      | env | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    When I run the :describe client command with:
      | resource | buildconfig |
      | name | <%= cb.appname4 %> |
    Then the output should match "Ref:\s+master"
    #Check invalid branch
    Given an 8 character random string of type :dns952 is stored into the :appname5 clipboard
    When I run the :new_app client command with:
      | code | https://github.com/openshift/ruby-hello-world#invalid |
      | image_stream | openshift/ruby |
      | name | <%= cb.appname5 %> |
      | env | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    Then the output should contain "error"
    #Check non-master branch
    Given an 8 character random string of type :dns952 is stored into the :appname6 clipboard
    When I run the :new_app client command with:
      | code | https://github.com/openshift/ruby-hello-world#beta4 |
      | image_stream | openshift/ruby |
      | name | <%= cb.appname6 %> |
      | env | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    When I run the :describe client command with:
      | resource | buildconfig |
      | name | <%= cb.appname6 %> |
    Then the output should match "Ref:\s+beta4"
    #Check non-existing docker file
    Then I run the :new_app client command with:
     | app_repo | https://github.com/openshift-qe/sample-php |
     | strategy | docker |
    Then the step should fail
    And the output should contain "No Dockerfile"

  # @author cryan@redhat.com
  # @case_id 474039
  Scenario: update multiple existing resources with file
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    Then the step should succeed
    Given the "ruby-sample-build-1" build completes
    Given 1 pods become ready with labels:
      | deployment=frontend-1 |
    #Change pod labels
    When I run the :patch client command with:
      | resource | pod |
      | resource_name | <%= pod.name %> |
      | p | {"metadata": {"labels": {"name":"changed"}}} |
    Then the step should succeed
    #Change buildconfig uri
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby-sample-build |
      | p | {"spec": {"source": {"git": {"uri": "https://github.com/openshift/origin"}}}} |
    Then the step should succeed
    #Change service labels
    Given I replace resource "services" named "frontend" saving edit to "serviceschange.json":
      | app: ruby-sample-build | app: change |
    When I run the :get client command with:
      | resource | pods |
      | resource_name | <%= pod.name %> |
      | o | json |
    Then the step should succeed
    Given I save the output to file> podschange.json
    When I run the :get client command with:
      | resource | buildconfigs |
      | o | json |
    Then the step should succeed
    Given I save the output to file> buildconfigschange.json
    #Services are missing here, because they were replaced in the
    #substitution above
    When I run the :replace client command with:
      | f | podschange.json |
      | f | buildconfigschange.json |
    Then the step should succeed
    #Verify changes, and at the same time save the output to a directory
    #and make new changes simultaneously.
    Given I create the "change" directory
    When I run the :get client command with:
      | resource | services |
      | o | json |
    Then the output should contain:
      | "app": "change" |
    Given I save the output to file> change/services.json
    Given I replace lines in "change/services.json":
      | "app": "change" | "app": "change2" |
    When I run the :get client command with:
      | resource | pods |
      | resource_name | <%= pod.name %> |
      | o | json |
    Then the output should contain:
      | "name": "changed" |
    Given I save the output to file> change/pods.json
    Given I replace lines in "change/pods.json":
      | "name": "changed" | "name": "changed2" |
    When I run the :get client command with:
      | resource | buildconfigs |
      | o | json |
    Then the output should contain:
      | "uri": "https://github.com/openshift/origin" |
    Given I save the output to file> change/buildconfig.json
    Given I replace lines in "change/buildconfig.json":
      | "uri": "https://github.com/openshift/origin" | "uri": "https://github.com/openshift/rails-ex" |
    When I run the :replace client command with:
      | f | change/ |
    Then the step should succeed
    When I run the :get client command with:
      | resource | services |
      | o | json |
    Then the output should contain:
      | "app": "change2" |
    When I run the :get client command with:
      | resource | pods |
      | resource_name | <%= pod.name %> |
      | o | json |
    Then the output should contain:
      | "name": "changed2" |
    When I run the :get client command with:
      | resource | buildconfigs |
      | o | json |
    Then the output should contain:
      | "uri": "https://github.com/openshift/rails-ex" |
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    Given the "ruby-sample-build-2" build completes
