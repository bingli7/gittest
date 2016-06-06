Feature: build 'apps' with CLI

  # @author xxing@redhat.com
  # @case_id 489753
  Scenario: Create a build config from a remote repository using branch
    Given I have a project
    When I run the :new_build client command with:
      | code           | https://github.com/openshift/ruby-hello-world#beta2 |
      | e              | key1=value1,key2=value2,key3=value3                 |
      | image_stream   | openshift/ruby                                      |
    Then the step should succeed
    When I run the :get client command with:
      | resource          | buildConfig      |
      | resource_name     | ruby-hello-world |
      | o                 | yaml             |
    Then the output should match:
      | uri:\\s+https://github.com/openshift/ruby-hello-world|
      | ref:\\s+beta2                                        |
      | name: key1                                           |
      | value: value1                                        |
      | name: key2                                           |
      | value: value2                                        |
      | name: key3                                           |
      | value: value3                                        |
    And I wait up to 20 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | builds |
    Then the output should contain:
      | NAME                |
      | ruby-hello-world-1  |
    """
    When I run the :get client command with:
      |resource| imageStream |
    Then the output should contain:
      | ruby-hello-world |

  # @author cryan@redhat.com
  # @case_id 489741
  Scenario: Create a build config based on the provided image and source code
    Given I have a project
    When I run the :new_build client command with:
      | code         | https://github.com/openshift/ruby-hello-world |
      | image        | openshift/ruby                                |
      | l            | app=rubytest                                  |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc               |
      | name     | ruby-hello-world |
    Then the output should match:
      | URL:\\s+https://github.com/openshift/ruby-hello-world|
    Given the pod named "ruby-hello-world-1-build" becomes ready
    When I run the :get client command with:
      | resource | builds |
    Then the output should contain:
      | NAME                |
      | ruby-hello-world-1  |
    When I run the :get client command with:
      |resource| is |
    Then the output should contain:
      | ruby-hello-world |
    When I run the :new_build client command with:
      | app_repo |  openshift/ruby:2.0~https://github.com/openshift/ruby-hello-world.git |
      | strategy | docker                                                                |
      | name     | n1                                                                    |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc               |
      | name     | ruby-hello-world |
    Then the output should match:
      | URL:\\s+https://github.com/openshift/ruby-hello-world|
    Given the pod named "n1-1-build" becomes ready
    When I run the :get client command with:
      | resource | builds |
    Then the output should contain:
      | NAME                |
      | n1-1 |
    When I run the :get client command with:
      |resource| is |
    Then the output should contain:
      | ruby-hello-world |

  # @author chunchen@redhat.com
  # @case_id 476356, 476357
  Scenario Outline: [origin_devexp_288] Push image with Docker credentials for build
    Given I have a project
    When I run the :new_app client command with:
      | app_repo        | <app_repo>                  |
      | context_dir     | <context_dir>               |
    Then the step should succeed
    Given the "<first_build_name>" build was created
    And the "<first_build_name>" build completed
    When I run the :describe client command with:
      | resource        | build                       |
      | name            | <first_build_name>          |
    Then the output should match:
      | Status:.*Complete                             |
      | Push Secret:.*builder\-dockercfg\-[a-zA-Z0-9]+|
    When I run the :new_secret client command with:
      | secret_name     | sec-push                    |
      | credential_file | <dockercfg_file>            |
    Then the step should succeed
    When I run the :add_secret client command with:
      | sa_name         | builder                     |
      | secret_name     | sec-push                    |
    Then the step should succeed
    When I run the :new_app client command with:
      | file            | <template_file>             |
    Given the "<second_build_name>" build was created
    And the "<second_build_name>" build completed
    When I run the :describe client command with:
      | resource        | build                       |
      | name            | <second_build_name>         |
    Then the output should match:
      | Status:.*Complete                             |
      | Push Secret:.*sec\-push                       |
    When I run the :build_logs client command with:
      | build_name      | <second_build_name>         |
    Then the output should match "Successfully pushed .*<output_image>"
    Examples:
      | app_repo                                                            | context_dir                  | first_build_name   | second_build_name          | template_file | output_image | dockercfg_file |
      | openshift/python-33-centos7~https://github.com/openshift/sti-python | 3.3/test/standalone-test-app | sti-python-1       | python-sample-build-sti-1  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc476357/application-template-stibuild.json        | aosqe\/python\-sample\-sti                  | <%= expand_private_path(conf[:services, :docker_hub, :dockercfg]) %>       |
      | https://github.com/openshift/ruby-hello-world.git                   |                              | ruby-hello-world-1 | ruby-sample-build-1        | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc476356/application-template-dockerbuild.json     | aosqe\/ruby\-sample\-docker                 | <%= expand_private_path(conf[:services, :docker_hub, :dockercfg]) %>       |

  # @author xxing@redhat.com
  # @case_id 491409
  Scenario: Create an application with multiple images and same repo
    Given I create a new project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-rhel7.json |
    Then the step should succeed
    Given the "ruby" image stream was created 
    And the "ruby" image stream becomes ready
    When I run the :new_app client command with:
      | image_stream | openshift/ruby:latest |
      | image_stream | <%= project.name %>/ruby:2.0 |
      | code         | https://github.com/openshift/ruby-hello-world |
      | l            | app=test |
    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :get client command with:
      |resource| buildConfig |
    Then the output should match:
      | NAME\\s+TYPE                 |
      | <%= Regexp.escape("ruby-hello-world") %>\\s+Source   |
      | <%= Regexp.escape("ruby-hello-world-1") %>\\s+Source |
    """
    When I run the :describe client command with:
      | resource | buildConfig      |
      | name     | ruby-hello-world |
    Then the output should match:
      | ImageStreamTag openshift/ruby |
    When I run the :describe client command with:
      | resource | buildConfig      |
      | name     | ruby-hello-world-1 |
    Then the output should match:
      | ImageStreamTag <%= Regexp.escape(project.name) %>/ruby:2.0 |
    Given the "ruby-hello-world-1" build completed
    Given the "ruby-hello-world-1-1" build completed
    Given I wait for the "ruby-hello-world" service to become ready
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl                       |
      | -k                         |
      | <%= service.url %>         |
    Then the step should succeed
    """
    And the output should contain "Demo App"
    Given I wait for the "ruby-hello-world-1" service to become ready
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl                       |
      | -k                         |
      | <%= service.url %>         |
    Then the step should succeed
    """
    And the output should contain "Demo App"

  # @author xxing@redhat.com
  # @case_id 482198
  Scenario: Set dump-logs and restart flag for cancel-build in openshift
    Given I have a project
    When I run the :process client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-template-sti.json |
    Then the step should succeed
    Given I save the output to file>app-stibuild.json
    When I run the :create client command with:
      | f | app-stibuild.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource | buildConfig |
    Then the output should contain:
      | NAME              |
      | ruby-sample-build |
    # As the trigger of bc is "ConfigChange" and sometime the first build doesn't create quickly,
    # so wait the first build complete，wanna start maunally for testing this cli well
    Given the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :cancel_build client command with:
      | build_name | ruby-sample-build-2 |
      | dump_logs  | true                |
    Then the output should contain:
      | Build logs for ruby-sample-build-2 |
    # "cancelled" comes quickly after "failed" status, wait
    # "failed" has the same meaning
    Given the "ruby-sample-build-2" build was cancelled
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :cancel_build client command with:
      | build_name | ruby-sample-build-3 |
      | restart    | true                |
      | dump_logs  | true                |
    Then the output should contain:
      | Build logs for ruby-sample-build-3 |
    Given the "ruby-sample-build-3" build was cancelled
    When I run the :get client command with:
      | resource | build |
    # Should contain the new start build
    Then the output should match:
      | <%= Regexp.escape("ruby-sample-build-4") %>.+(?:Running)?(?:Pending)?|


  # @author xiaocwan@redhat.com
  # @case_id 482200
  Scenario: Cancel a build in openshift
    Given I have a project
    When I process and create "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-template-sti.json"
    Then the step should succeed
    When I get project buildConfigs
    Then the output should contain:
      | NAME              |
      | ruby-sample-build |
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build|
    Then the step should succeed
    And the "ruby-sample-build-1" build was created

    Given the "ruby-sample-build-1" build becomes :running
    Then the step should succeed
    When I run the :cancel_build client command with:
      | build_name | ruby-sample-build-1 |
    Then the "ruby-sample-build-1" build was cancelled
    When I get project pods
    Then the output should not contain:
      |  ruby-sample-build-3-build  |
    When I get project builds
    Then the output should contain:
      |  ruby-sample-build-2  |
    When I get project pods
    Then the output should contain:
      |  ruby-sample-build-2-build  |

    When I run the :cancel_build client command with:
      | build_name | non-exist |
    Then the step should fail

    When the "ruby-sample-build-2" build completed
    And I run the :cancel_build client command with:
      | build_name | ruby-sample-build-2 |
    Then the "ruby-sample-build-2" build completed


  # @author xiuwang@redhat.com
  # @case_id 491258
  Scenario: Create applications with multiple groups
    Given I create a new project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-rhel7.json |
    Given the "ruby" image stream was created
    And the "ruby" image stream becomes ready
    Given the "mysql" image stream was created
    And the "mysql" image stream becomes ready
    Given the "postgresql" image stream was created
    And the "postgresql" image stream becomes ready
    When I run the :new_app client command with:
      | image_stream | openshift/ruby |
      | image_stream | <%= project.name %>/ruby:2.2 |
      | docker_image | <%= product_docker_repo %>rhscl/ruby-22-rhel7 |
      | image_stream | openshift/mysql |
      | image_stream | <%= project.name %>/mysql:5.5 |
      | docker_image | <%= product_docker_repo %>rhscl/mysql-56-rhel7 |
      | image_stream | openshift/postgresql |
      | image_stream | <%= project.name %>/postgresql:9.2 |
      | docker_image | <%= product_docker_repo %>rhscl/postgresql-94-rhel7 |
      | group        | openshift/ruby+openshift/mysql+openshift/postgresql |
      | group        | <%= project.name %>/ruby:2.2+<%= project.name %>/mysql:5.5+<%= project.name %>/postgresql:9.2 |
      | group        | <%= product_docker_repo %>rhscl/ruby-22-rhel7+<%= product_docker_repo %>rhscl/mysql-56-rhel7+<%= product_docker_repo %>rhscl/postgresql-94-rhel7 |
      | code         | https://github.com/openshift/ruby-hello-world |
      | env          | POSTGRESQL_USER=user,POSTGRESQL_DATABASE=db,POSTGRESQL_PASSWORD=test,MYSQL_ROOT_PASSWORD=test |
      | l            | app=testapps    |
      | insecure_registry | true |
    Then the step should succeed
    When I run the :get client command with:
      |resource| buildConfig |
    Then the output should match:
      | NAME\\s+TYPE                 |
      | <%= Regexp.escape("ruby-hello-world") %>\\s+Source   |
      | <%= Regexp.escape("ruby-hello-world-1") %>\\s+Source |
      | <%= Regexp.escape("ruby-hello-world-2") %>\\s+Source |
    When I run the :describe client command with:
      | resource | buildConfig      |
      | name     | ruby-hello-world |
    Then the output should match:
      | ImageStreamTag ruby-22-rhel7:latest |
    When I run the :describe client command with:
      | resource | buildConfig        |
      | name     | ruby-hello-world-1 |
    Then the output should match:
      | ImageStreamTag openshift/ruby:2.2 |
    When I run the :describe client command with:
      | resource | buildConfig        |
      | name     | ruby-hello-world-2 |
    Then the output should match:
      | ImageStreamTag <%= Regexp.escape(project.name) %>/ruby:2.2 |
    Given the "ruby-hello-world-1" build completed
    Given the "ruby-hello-world-1-1" build completed
    Given the "ruby-hello-world-2-1" build completed
    Given I wait for the "mysql-56-rhel7" service to become ready
    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :exec client command with:
      | pod          | <%= pod.name %>  |
      | c            | ruby-hello-world |
      | oc_opts_end  ||
      | exec_command | curl  |
      | exec_command | -k    |
      | exec_command | <%= service.ip %>:8080 |
    Then the step should succeed
    """
    And the output should contain "Demo App"
    Given I wait for the "postgresql" service to become ready
    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :exec client command with:
      | pod          | <%= pod.name %>    |
      | c            | ruby-hello-world-1 |
      | oc_opts_end  ||
      | exec_command | curl  |
      | exec_command | -k    |
      | exec_command | <%= service.ip %>:8080 |
    Then the step should succeed
    """
    And the output should contain "Demo App"
    Given I wait for the "ruby-hello-world-2" service to become ready
    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :exec client command with:
      | pod          | <%= pod.name %>    |
      | c            | ruby-hello-world-2 |
      | oc_opts_end  ||
      | exec_command | curl  |
      | exec_command | -k    |
      | exec_command | <%= service.ip %>:8080 |
    Then the step should succeed
    """
    And the output should contain "Demo App"

  # @author cryan@redhat.com
  # @case_id 474049
  Scenario: Stream logs back automatically after start build
    Given I have a project
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-sti.json"
    Given I replace lines in "ruby22rhel7-template-sti.json":
      | registry.access.redhat.com/ | <%= product_docker_repo %> |
    When I run the :new_app client command with:
      | file | ruby22rhel7-template-sti.json |
    Then the step should succeed
    When I get project buildconfigs
    Then the step should succeed
    And the output should contain "ruby22-sample-build"
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
      | follow | true |
      | wait   | true |
      | _timeout | 120|
    And the output should contain:
      | Installing application source |
      | Building your Ruby application from source |
    When I run the :start_build client command with:
      | from_build | ruby22-sample-build-1 |
      | follow | true |
      | wait   | true |
      | _timeout | 120|
    And the output should contain:
      | Installing application source |
      | Building your Ruby application from source |
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | p | {"spec":{"source":{"git":{"uri":"https://nondomain.com"}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
      | follow | true |
      | wait   | true |
      | _timeout | 120|
    Then the output should contain "unable to access 'https://nondomain.com/"

  # @author cryan@redhat.com
  # @case_id 479022
  Scenario: Add ENV with CustomStrategy when do custom build
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc479022/application-template-custombuild.json |
    Then the step should succeed
    Given the "ruby-sample-build-1" build completed
    When I run the :env client command with:
      | resource | pod |
      | env_name | ruby-sample-build-1-build |
      | list | true |
    Then the output should contain "http_proxy=http://squid.example.com:3128"

  # @author cryan@redhat.com
  # @case_id 507557
  Scenario: Add more ENV to DockerStrategy buildConfig when do docker build
    Given I have a project
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-docker.json"
    Given I replace lines in "ruby22rhel7-template-docker.json":
      | registry.access.redhat.com/ | <%= product_docker_repo %> |
    When I run the :new_app client command with:
      | file | ruby22rhel7-template-docker.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      |deployment=frontend-1|
    Given evaluation of `@pods[0].name` is stored in the :frontendpod clipboard
    When I run the :build_logs client command with:
      | build_name | ruby22-sample-build-1 |
    Then the output should contain:
      | ENV RACK_ENV production  |
      | ENV RAILS_ENV production |
    When I execute on the "<%= cb.frontendpod %>" pod:
      | env |
    Then the step should succeed
    And the output should contain "RACK_ENV=production"
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | p | {"spec": {"strategy": {"dockerStrategy": {"env": [{"name": "DISABLE_ASSET_COMPILATION","value": "1"}, {"name":"RACK_ENV","value":"development"}]}}}} |
    Then the step should succeed
    When I run the :get client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | o | json |
    Then the output should contain "DISABLE_ASSET_COMPILATION"
    And the output should contain "RACK_ENV"
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    When I run the :build_logs client command with:
      | build_name | ruby22-sample-build-2 |
    Then the output should contain:
      | ENV "DISABLE_ASSET_COMPILATION" "1" |
      | "RACK_ENV" "development"  |
    Given 2 pods become ready with labels:
      |deployment=frontend-2|
    Given evaluation of `@pods[2].name` is stored in the :frontendpod2 clipboard
    When I execute on the "<%= cb.frontendpod2 %>" pod:
      | env |
    Then the step should succeed
    And the output should contain "RACK_ENV=production"

  # @author cryan@redhat.com
  # @case_id 498212
  Scenario: Order builds according to creation timestamps
    Given I have a project
    And I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    Given the "ruby-22-centos7" image stream was created 
    And the "ruby-22-centos7" image stream becomes ready
    And I run the :start_build client command with:
      | buildconfig |  ruby-sample-build |
    And I run the :start_build client command with:
      | buildconfig |  ruby-sample-build |
    And I run the :start_build client command with:
      | buildconfig |  ruby-sample-build |
    And I run the :get client command with:
      | resource | builds |
    Then the output by order should match:
      | ruby-sample-build-1 |
      | ruby-sample-build-2 |
      | ruby-sample-build-3 |
      | ruby-sample-build-4 |

  # @author pruan@redhat.com
  # @case_id 512096
  Scenario: Start build with option --wait
    Given I have a project
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc512096/test-build-cancle.json |
    Then the step should succeed
    And I run the :start_build client command with:
      | buildconfig | sample-build |
      | wait        | true         |
    Then the step should succeed
    And I run the :start_build client command with:
      | buildconfig | sample-build |
      | wait        | true         |
      | commit      | deadbeef     |
    Then the step should fail
    And I run the :start_build background client command with:
      | buildconfig | sample-build |
      | wait        | true         |
    Given the pod named "sample-build-3-build" is present
    And I run the :cancel_build client command with:
      | build_name | sample-build-3 |
    And the output should match:
      | Build sample-build-3 was cancelled |

  # @author pruan@redhat.com
  # @case_id 517369, 517370, 517367, 517368
  Scenario Outline: when delete the bc,the builds pending or running should be deleted
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc<number>/test-buildconfig.json |
    Then the step should succeed
    Given the "ruby-sample-build-1" build becomes <build_status>
    Then I run the :delete client command with:
      | object_type | buildConfig |
      | object_name_or_id | ruby-sample-build |
    Then the step should succeed
    And I run the :get client command with:
      | resource | buildConfig |
    Then the output should not contain:
      | ruby-sample-build |
    And I run the :get client command with:
      | resource | build |
    Then the output should not contain:
      | ruby-sample-build |

    Examples:
      | number | build_status |
      | 517369 | :pending     |
      | 517370 | :running     |
      | 517367 | :complete    |
      | 517368 | :failed      |

  # @author pruan@redhat.com
  # @case_id 517366
  Scenario: Recreate bc when previous bc is deleting pending
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/test-buildconfig.json |
    Then the step should succeed
    Given the "ruby-sample-build-1" build completed
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby-sample-build |
      | p | {"metadata": {"annotations": {"openshift.io/build-config.paused": "true"}}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | buildConfig |
    Then the output should contain:
      | build-config.paused=true |
    And I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should fail
    And the output should match:
      | Error from server: fatal error generating Build from BuildConfig: can't instantiate from BuildConfig <%= project.name %>/ruby-sample-build: BuildConfig is paused |
    When I run the :start_build client command with:
      | from_build | ruby-sample-build-1 |
    Then the step should fail
    And the output should match:
      | Error from server: fatal error generating Build from BuildConfig: can't instantiate from BuildConfig <%= project.name %>/ruby-sample-build: BuildConfig is paused |
    Then I run the :delete client command with:
      | object_type | buildConfig |
      | object_name_or_id | ruby-sample-build |
    Then the step should succeed
    And I run the :get client command with:
      | resource | buildConfig |
    Then the output should not contain:
      | ruby-sample-build |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/test-buildconfig.json |
    Then the step should succeed
    Then the "ruby-sample-build-1" build completed
    And I run the :delete client command with:
      | object_type | buildConfig |
      | object_name_or_id | ruby-sample-build |
      | cascade           | false             |
    Then the step should succeed
    And I run the :get client command with:
      | resource | buildConfig |
    Then the output should not contain:
      | ruby-sample-build |
    And I run the :get client command with:
      | resource | build |
    Then the output should contain:
      | ruby-sample-build |

  # @author pruan@redhat.com
  # @case_id 512260
  Scenario: oc start-build with a directory passed,sti build type
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | https://github.com/openshift/nodejs-ex |
    Then the step should succeed
    And the "nodejs-ex-1" build completed
    And I git clone the repo "https://github.com/openshift/nodejs-ex"
    And I run the :start_build client command with:
      | buildconfig | nodejs-ex |
      | from_dir    | nodejs-ex |
    Given I wait for the steps to pass:
    """
    Given the pod named "nodejs-ex-2-build" is present
    """
    Given the pod named "nodejs-ex-2-build" status becomes :succeeded
    Given the "tmp/test/testfile" file is created with the following lines:
    """
    This is a test!
    """
    And I run the :start_build client command with:
      | buildconfig | nodejs-ex |
      | from_dir    | tmp/test |
    Then the step should succeed
    And I run the :get client command with:
      | resource | build |
    Given the pod named "nodejs-ex-3-build" status becomes :failed
    And I run the :start_build client command with:
      | buildconfig | nodejs-ex |
      | from_dir    | tmp/deadbeef |
    Then the step should fail
    And the output should contain:
      | deadbeef: no such file or directory |

  # @author pruan@redhat.com
  # @case_id 512259
  Scenario: oc start-build with a directory passed ,using sti build type, with context-dir
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | https://github.com/openshift/sti-nodejs.git |
      | context_dir | 0.10/test/test-app/                      |
    Then the step should succeed
    Then the "sti-nodejs-1" build completed
    Given I git clone the repo "https://github.com/openshift/sti-nodejs.git"
    When I run the :start_build client command with:
      | buildconfig | sti-nodejs |
      | from_dir | sti-nodejs |
    And the "sti-nodejs-2" build completed

  # @author pruan@redhat.com
  # @case_id 512261
  Scenario: oc start-build with a file passed,Docker build type
    Given I have a project
    When I run the :new_app client command with:
      | app_repo |  openshift/ruby:2.2~https://github.com/openshift/ruby-hello-world.git |
      | strategy |  docker                                                               |
    Then the step should succeed
    Then the "ruby-hello-world-1" build completed
    Given a "Dockerfile" file is created with the following lines:
    """
    FROM openshift/ruby-22-centos7
    USER default
    EXPOSE 8080
    ENV RACK_ENV production
    ENV RAILS_ENV production
    """
    And I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
      | from_file   | ./Dockerfile     |
    Then the step should succeed
    Then the "ruby-hello-world-2" build completed
    # start build with non-existing file
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world         |
      | from_file   | ./non-existing-file-name |
    Then the step should fail
    And the output should contain "no such file or directory"

  # @author pruan@redhat.com
  # @case_id 512266
  Scenario: oc start-build with a zip,tar,or tar.gz passed,using Docker build type
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-docker.json |
    Then the step should succeed
    And the "ruby22-sample-build-1" build completes
    And I download a file from "https://github.com/openshift-qe/v3-testfiles/raw/master/build/shared_compressed_files/ruby-hello-world.zip"
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build       |
      | from_dir    | -                         |
      | _stdin      | <%= @result[:response] %> |
      | _binmode    |                           |
    Then the step succeeded
    Then the "ruby22-sample-build-2" build completes
    And I download a file from "https://github.com/openshift-qe/v3-testfiles/raw/master/build/shared_compressed_files/ruby-hello-world.tar"
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build       |
      | from_dir    | -                         |
      | _stdin      | <%= @result[:response] %> |
      | _binmode    |                           |
    Then the step succeeded
    Then the "ruby22-sample-build-3" build completes
    And I download a file from "https://github.com/openshift-qe/v3-testfiles/raw/master/build/shared_compressed_files/ruby-hello-world.tar.gz"
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build       |
      | from_dir    | -                         |
      | _stdin      | <%= @result[:response] %> |
      | _binmode    |                           |
    Then the step succeeded
    Then the "ruby22-sample-build-4" build completes
    And I download a file from "https://github.com/openshift-qe/v3-testfiles/raw/master/build/shared_compressed_files/test.zip"
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build       |
      | from_dir    | -                         |
      | _stdin      | <%= @result[:response] %> |
      | _binmode    |                           |
    Then the step should succeed
    And the "ruby22-sample-build-5" build fails

  # @author pruan@redhat.com
  # @case_id 512267
  Scenario: oc start-build with a zip,tar,or tar.gz passed,using sti build type
    Given I have a project
    When I run the :new_app client command with:
      | app_repo |   https://github.com/openshift/nodejs-ex |
    Then the step should succeed
    Then the "nodejs-ex-1" build completes
    And I download a file from "https://github.com/openshift-qe/v3-testfiles/raw/master/build/shared_compressed_files/nodejs-ex.zip"
    When I run the :start_build client command with:
      | buildconfig | nodejs-ex                 |
      | from_dir    | -                         |
      | _stdin      | <%= @result[:response] %> |
      | _binmode    |                           |
    Then the step succeeded
    Then the "nodejs-ex-2" build completes
    And I download a file from "https://github.com/openshift-qe/v3-testfiles/raw/master/build/shared_compressed_files/nodejs-ex.tar"
    When I run the :start_build client command with:
      | buildconfig | nodejs-ex                 |
      | from_dir    | -                         |
      | _stdin      | <%= @result[:response] %> |
      | _binmode    |                           |
    Then the step succeeded
    Then the "nodejs-ex-3" build completes
    And I download a file from "https://github.com/openshift-qe/v3-testfiles/raw/master/build/shared_compressed_files/nodejs-ex.tar.gz"
    When I run the :start_build client command with:
      | buildconfig | nodejs-ex                 |
      | from_dir    | -                         |
      | _stdin      | <%= @result[:response] %> |
      | _binmode    |                           |
    Then the step succeeded
    Then the "nodejs-ex-4" build completes
    And I download a file from "https://github.com/openshift-qe/v3-testfiles/raw/master/build/shared_compressed_files/test.zip"
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | nodejs-ex                 |
      | from_dir    | -                         |
      | _stdin      | <%= @result[:response] %> |
      | _binmode    |                           |
    Then the step should succeed
    And the "nodejs-ex-5" build fails

  # @author pruan@redhat.com
  # @case_id 512268
  Scenario: oc start-build with a zip,tar,or tar.gz passed,using sti build type, with context-dir
    Given I have a project
    When I run the :new_app client command with:
      | app_repo    | https://github.com/openshift/sti-nodejs.git |
      | context_dir | 0.10/test/test-app/                         |
    Then the step should succeed
    And the "sti-nodejs-1" build completes
    And I download a file from "https://github.com/openshift-qe/v3-testfiles/raw/master/build/shared_compressed_files/sti-nodejs.zip"
    When I run the :start_build client command with:
      | buildconfig | sti-nodejs                |
      | from_dir    | -                         |
      | _stdin      | <%= @result[:response] %> |
      | _binmode    |                           |
    And the "sti-nodejs-2" build completes

  # @author pruan@redhat.com
  # @case_id 512258
  Scenario: oc start-build with a directory passed ,using Docker build type
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-docker.json |
    Then the step should succeed
    And the "ruby22-sample-build-1" build completes
    And I git clone the repo "https://github.com/openshift/ruby-hello-world.git"
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
      | from_dir    | ruby-hello-world    |
    Then the step should succeed
    And the "ruby22-sample-build-2" build completes
    Given I create the "tc512258" directory
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
      | from_dir    | tc512258            |
    Then the step should succeed
    And the "ruby22-sample-build-3" build fails
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
      | from_dir    | dir_not_exist       |
    Then the step should fail
    And the output should contain:
      | no such file or directory |

  # @author cryan@redhat.com
  # @case_id 519487
  Scenario: Implement post-build command for s2i build
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-sti.json |
    Given the "ruby22-sample-build-1" build completes
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | p | {"spec":{"postCommit":{"script":"bundle exec rake test"}}} |
    Then the step should succeed
    When I run the :get client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | o | json |
    Then the output should contain "postCommit"
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Given the "ruby22-sample-build-2" build completes
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | p | {"spec":{"postCommit":{"command": ["/bin/bash", "-c", "bundle exec rake test --verbose"], "args": null, "script":null}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Given the "ruby22-sample-build-3" build completes
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | p | {"spec":{"postCommit": {"args": ["bundle","exec","rake","test","--verbose"]}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Given the "ruby22-sample-build-4" build completes
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | p | {"spec":{"postCommit": {"args": ["--verbose"],"command":null, "script": "bundle exec rake test $1"}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Given the "ruby22-sample-build-5" build completes

  # @author cryan@redhat.com
  # @case_id 519486
  Scenario: Implement post-build command for quickstart: Django
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc519486/django.json |
    Given the "django-example-1" build completes
    When I run the :build_logs client command with:
      | build_name | django-example-1 |
    Then the output should match "Ran \d+ tests"
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc519486/django-postgresql.json |
    Given the "django-psql-example-1" build completes
    When I run the :build_logs client command with:
      | build_name | django-psql-example-1 |
    Then the output should match "Ran \d+ tests"

  # @author xiuwang@redhat.com
  # @case_id 489748
  Scenario: Create a build config based on the source code in the current git repository
    Given I have a project
    And I git clone the repo "https://github.com/openshift/ruby-hello-world.git"
    When I run the :new_build client command with:
      | image | openshift/ruby   |
      | code  | ruby-hello-world |
      | e     | FOO=bar          |
      | name  | myruby           |
    Then the step should succeed
    And the "myruby-1" build was created
    And the "myruby-1" build completed
    When I run the :get client command with:
      | resource          | buildConfig |
      | resource_name     | myruby      |
      | o                 | yaml        |
    Then the output should match:
      | uri:\\s+https://github.com/openshift/ruby-hello-world |
      | name:\\s+FOO  |
      | value:\\s+bar |
    When I run the :get client command with:
      | resource          | imagestream |
      | resource_name     | myruby      |
      | o                 | yaml        |
    Then the output should match:
      | tag:\\s+latest |

    When I run the :new_build client command with:
      | code  | ruby-hello-world |
      | strategy | source        |
      | e     | key1=value1,key2=value2,key3=value3 |
      | name  | myruby1          |
    Then the step should succeed
    And the "myruby1-1" build was created
    And the "myruby1-1" build completed
    When I run the :get client command with:
      | resource          | buildConfig |
      | resource_name     | myruby1     |
      | o                 | yaml        |
    Then the output should match:
      | sourceStrategy:  |
      | name:\\s+key1    |
      | value:\\s+value1 |
      | name:\\s+key2    |
      | value:\\s+value2 |
      | name:\\s+key3    |
      | value:\\s+value3 |
      | type:\\s+Source  |

    When I run the :new_build client command with:
      | code  | ruby-hello-world |
      | e     | @#@=value        |
      | name  | myruby2          |
    Then the step should fail
    And the output should contain:
      |error: environment variables must be of the form key=value: @#@=value|

  # @author xiuwang@redhat.com
  # @case_id 491406
  Scenario: Create applications only with multiple db images
    Given I create a new project
    When I run the :new_app client command with:
      | image_stream | openshift/mongodb |
      | image_stream | openshift/mysql   |
      | docker_image | <%= product_docker_repo %>rhscl/postgresql-94-rhel7 |
      | env          | MONGODB_USER=test,MONGODB_PASSWORD=test,MONGODB_DATABASE=test,MONGODB_ADMIN_PASSWORD=test |
      | env          | POSTGRESQL_USER=user,POSTGRESQL_DATABASE=db,POSTGRESQL_PASSWORD=test |
      | env          | MYSQL_ROOT_PASSWORD=test |
      | l            | app=testapps      |
      | insecure_registry | true         |
    Then the step should succeed

    Given I wait for the "mysql" service to become ready
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | bash | -c | mysql  -h $MYSQL_SERVICE_HOST -u root -ptest -e "show databases" |
    Then the step should succeed
    """
    And the output should contain "mysql"
    Given I wait for the "mongodb" service to become ready
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | scl | enable | rh-mongodb26 | mongo $MONGODB_DATABASE -u $MONGODB_USER -p $MONGODB_PASSWORD  --eval 'db.version()' |
    Then the step should succeed
    """
    And the output should contain:
      | 2.6 |
    Given I wait for the "postgresql-94-rhel7" service to become ready
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | bash |
      | -c |
      | psql -U user -c 'CREATE TABLE tbl (col1 VARCHAR(20), col2 VARCHAR(20));' db |
    Then the step should succeed
    """
    And the output should contain:
      | CREATE TABLE |

  # @author cryan@redhat.com
  # @case_id 519263
  Scenario: Can't allocate out of limits resources to container which builder pod launched for docker build
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-docker.json |
    Then the step should succeed
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | p | {"spec":{"resources": {"requests": {"cpu": "600m","memory": "200Mi"},"limits": {"cpu": "800m","memory": "200Mi"}}}} |
    Then the step should succeed
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | p | {"spec": {"source": {"git": {"uri": "git://github.com/openshift-qe/ruby-cgroup-test.git","ref":"memlarge"}}}} |
    Then the step should succeed
    Then I run the :delete client command with:
      | object_type       | builds                |
      | object_name_or_id | ruby22-sample-build-1 |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Given the "ruby22-sample-build-2" build fails
    When I run the :build_logs client command with:
      | build_name | ruby22-sample-build-2 |
    Then the output should contain:
      | stress: FAIL |
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | p | {"spec": {"source": {"git": {"uri": "git://github.com/openshift-qe/ruby-cgroup-test.git","ref":"cpularge"}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the step should succeed
    Given the "ruby22-sample-build-3" build was created
    Given the "ruby22-sample-build-3" build completed
    When I run the :build_logs client command with:
      | build_name | ruby22-sample-build-3 |
    Then the output should contain:
      | cat /sys/fs/cgroup/cpuacct,cpu/cpu.shares        |
      | 614                                              |
      | cat /sys/fs/cgroup/cpuacct,cpu/cpu.cfs_period_us |
      | 100000                                           |
      | cat /sys/fs/cgroup/cpuacct,cpu/cpu.cfs_quota_us  |
      | 80000                                            |

  # @author cryan@redhat.com
  # @case_id 470341
  Scenario: Do sti build with the OnBuild instructions strategy and sti scripts via oc
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/template_onbuild.json |
    Given the "ruby-sample-build-1" build completes

  # @author cryan@redhat.com
  # @case_id 470327
  Scenario: Do source builds with blank builder image
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc470327/python-34-rhel7-stibuild.json |
    Then the step should fail
    And the output should contain "spec.strategy.sourceStrategy.from.name: Required value"

  # @author pruan@redhat.com
  # @case_id 519266
  Scenario: Check cgroup info in container which builder pod launched for s2i build
    Given I have a project
    When I run the :new_app client command with:
      | app_repo |  openshift/ruby:latest~https://github.com/openshift-qe/ruby-cgroup-test |
    Then the step should succeed
    Given the "ruby-cgroup-test-1" build becomes :running
    And I wait up to 60 seconds for the steps to pass:
    """
    And I run the :logs client command with:
      | resource_name | bc/ruby-cgroup-test |
    And the output should contain:
      | ===Cgroup info===                                |
      | cat /sys/fs/cgroup/memory/memory.limit_in_bytes  |
      | cat /sys/fs/cgroup/cpuacct,cpu/cpu.shares        |
      | cat /sys/fs/cgroup/cpuacct,cpu/cpu.cfs_period_us |
      | cat /sys/fs/cgroup/cpuacct,cpu/cpu.cfs_quota_us  |
    """

  # @author cryan@redhat.com
  # @case_id 517667
  Scenario: Add multiple source inputs
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc517667/ruby22rhel7-template-sti.json |
    Given the "ruby22-sample-build-1" build completes
    When I run the :get client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | o | yaml |
    Then the output should match "xiuwangs2i-2$"
    And the output should not match "xiuwangs2i$"
    Given 2 pods become ready with labels:
      |deployment=frontend-1|
    When I execute on the "<%= pod.name %>" pod:
      | ls | xiuwangs2i |
    Then the step should fail
    When I execute on the "<%= pod.name %>" pod:
      | ls |
    Then the step should succeed
    And the output should contain:
      | xiuwangs2i-2 |

  # @author cryan@redhat.com
  # @case_id 522440
  Scenario: Check bad proxy in .s2i/environment when performing s2i build
    Given I have a project
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-template-sti.json"
    Given I replace lines in "ruby20rhel7-template-sti.json":
      | "uri": "https://github.com/openshift/ruby-hello-world.git" | "uri": "https://github.com/openshift-qe/ruby-hello-world-badproxy.git" |
    Given I process and create "ruby20rhel7-template-sti.json"
    Given the "ruby-sample-build-1" build finishes
    When I run the :build_logs client command with:
      | build_name | ruby-sample-build-1 |
    Then the step should succeed
    And the output should contain "Could not fetch specs"

  # @author cryan@redhat.com
  # @case_id 482216
  Scenario: Add ENV vars to .sti/environment when do sti build in openshift
    Given I have a project
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-template-sti.json"
    Given I replace lines in "ruby20rhel7-template-sti.json":
      | "uri": "https://github.com/openshift/ruby-hello-world.git" | "uri": "https://github.com/openshift-qe/ruby-hello-world-tc482216.git" |
    Given I process and create "ruby20rhel7-template-sti.json"
    Given the "ruby-sample-build-1" build completes
    Given 2 pods become ready with labels:
      | name=frontend |
    When I execute on the "<%= pod.name %>" pod:
      | env |
    Then the output should contain "envtest1"

  # @author cryan@redhat.com
  # @case_id 483592
  Scenario: Sync build status after delete its related pod
    Given I have a project
    When I process and create "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/php-55-rhel7-stibuild.json"
    Then the step should succeed
    Given the pod named "php-sample-build-1-build" status becomes :running
    When I run the :delete client command with:
      | object_type | pod |
      | object_name_or_id | php-sample-build-1-build |
    Then the step should succeed
    Given the "php-sample-build-1" build finishes
    Given I get project builds
    Then the output should contain "Failed"
    When I run the :start_build client command with:
      | buildconfig | php-sample-build |
    Then the step should succeed
    Given the pod named "php-sample-build-2-build" status becomes :running
    When I run the :delete client command with:
      | object_type | pod |
      | object_name_or_id | php-sample-build-2-build |
    Then the step should succeed
    Given the "php-sample-build-2" build finishes
    Given I get project builds
    Then the output should contain "Failed"
    When I run the :start_build client command with:
      | buildconfig | php-sample-build |
    Then the step should succeed
    Given the "php-sample-build-3" build completes
    When I run the :delete client command with:
      | object_type | pod |
      | object_name_or_id | php-sample-build-3-build |
    Then the step should succeed
    When I run the :get client command with:
      | resource | builds |
      | resource_name | php-sample-build-3 |
    Then the output should contain "Complete"
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | php-sample-build |
      | p | {"spec": {"source": {"git": {"uri": "https://nonexist.com"}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | php-sample-build |
    Then the step should succeed
    Given the "php-sample-build-4" build finishes
    When I run the :get client command with:
      | resource | builds |
      | resource_name | php-sample-build-4 |
    Then the output should contain "Failed"
    When I run the :delete client command with:
      | object_type | pod |
      | object_name_or_id | php-sample-build-4-build |
    Then the step should succeed
    When I run the :get client command with:
      | resource | builds |
      | resource_name | php-sample-build-4 |
    Then the output should contain "Failed"

  # @author cryan@redhat.com
  # @case_id 521427
  Scenario: Overriding builder image scripts by invalid scripts in buildConfig
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/test-buildconfig.json |
    Then the step should succeed
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby-sample-build |
      | p | {"spec": {"strategy": {"sourceStrategy": {"scripts": "http:/foo.bar.com/invalid/assemble"}}}} |
      Then the step should succeed
      When I run the :start_build client command with:
        | buildconfig | ruby-sample-build |
      Then the step should succeed
      Given the "ruby-sample-build-2" build finishes
      When I run the :logs client command with:
        | resource_name | build/ruby-sample-build-2 |
      Then the step should succeed
      And the output should contain "Could not download"

  # @case_id 517666
  Scenario: Add a image with multiple paths as source input
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc517666/ruby22rhel7-template-sti.json |
    Given the "ruby22-sample-build-1" build completes
    When I run the :get client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | o | yaml |
    Then the output should contain "xiuwangs2i-2"
    Given 2 pods become ready with labels:
      | deployment=frontend-1 |
    When I execute on the "<%= pod.name %>" pod:
      | ls |
    Then the step should succeed
    And the output should contain "xiuwangs2i-2"

  # @author cryan@redhat.com
  # @case_id 521602
  Scenario: Overriding builder image scripts in buildConfig under invalid proxy
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/test-buildconfig.json |
    Then the step should succeed
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby-sample-build |
      | p | {"spec": {"strategy": {"sourceStrategy": {"scripts": "https://raw.githubusercontent.com/dongboyan77/builderimage-scripts/master/bin"}}}} |
    Then the step should succeed
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby-sample-build |
      | p | {"spec": {"strategy": {"sourceStrategy": {"env": [{"name":"http_proxy","value":"http://incorrect.proxy:3128"}]}}}} |
      Then the step should succeed
      When I run the :start_build client command with:
        | buildconfig | ruby-sample-build |
      Then the step should succeed
      Given the "ruby-sample-build-2" build finishes
      When I run the :logs client command with:
        | resource_name | build/ruby-sample-build-2 |
      Then the step should succeed
      And the output should contain "error connecting to proxy"

  # @author cryan@redhat.com
  # @case_id 517970
  Scenario: Specify build apiVersion for custom build
    Given I have a project
    When I process and create "https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-custombuild.json"
    Then the step should succeed
    Given the "ruby-sample-build-1" build completes
    Given I get project buildconfigs
    Then the output should contain:
      | ruby-sample-build |
      | Custom |
    When I run the :describe client command with:
      | resource | buildconfig |
      | name | ruby-sample-build |
    Then the output should contain:
      | ruby-sample-build |
      | Custom |
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby-sample-build |
      | p | {"spec": {"source": {"git": {"uri": "https://github.com/openshift-qe/ruby-hello-world"}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    Given the "ruby-sample-build-2" build completes
    When I run the :env client command with:
      | resource | pod/ruby-sample-build-2-build |
      | list | true |
    Then the step should succeed
    And the output should contain:
      | "apiVersion":"v1" |
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby-sample-build |
      | p | {"spec": {"strategy": {"customStrategy": {"buildAPIVersion": "v1beta3"}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    Given the "ruby-sample-build-3" build completes
    When I run the :env client command with:
      | resource | pod/ruby-sample-build-3-build |
      | list | true |
    Then the step should succeed
    And the output should contain:
      | "apiVersion":"v1beta3" |

  # @author cryan@redhat.com
  # @case_id 497657
  @admin
  @destructive
  Scenario: Allowing only certain users to create builds with a particular strategy
    Given cluster role "system:build-strategy-docker" is removed from the "system:authenticated" group
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-dockerbuild.json |
    Then the output should contain "build strategy Docker is not allowed"
    Given cluster role "system:build-strategy-docker" is added to the "first" user
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-dockerbuild.json |
    Given I get project builds
    Then the output should contain "ruby-sample-build-1"

  # @author cryan@redhat.com
  # @case_id 497701
  @admin
  @destructive
  Scenario: Can't start a new build when disable a build strategy globally after buildconfig has been created
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-dockerbuild.json |
    Then the step should succeed
    Given the "ruby-sample-build-1" build becomes :running
    Given I get project builds
    Then the output should contain "ruby-sample-build-1"
    Given cluster role "system:build-strategy-docker" is removed from the "system:authenticated" group
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the output should contain "Docker is not allowed"

  # @author dyan@redhat.com
  # @case_id 519593
  Scenario: oc new-build --binary should create BC according to the imagetype
    Given I have a project
    When I run the :new_build client command with:
      | binary | ruby |
    Then the step should succeed
    When I run the :get client command with:
      | resource | bc |
      | resource_name | ruby |
      | o             | yaml |
    Then the step should succeed
    And the output should contain:
      | sourceStrategy |
      | type: Source   |
    When I run the :new_build client command with:
      | binary | registry.access.redhat.com/rhscl/ruby-22-rhel7:latest |
      | to     | ruby1 |
    Then the step should succeed
    When I run the :get client command with:
      | resource | bc |
      | resource_name | ruby1 |
      | o             | yaml  |
    Then the step should succeed
    And the output should contain:
      | sourceStrategy |
      | type: Source   |
    When I run the :new_build client command with:
      | binary | ruby |
      | strategy | docker |
      | to     | ruby2 |
    Then the step should succeed
    When I run the :get client command with:
      | resource | bc |
      | resource_name | ruby2 |
      | o             | yaml |
    Then the step should succeed
    And the output should contain:
      | dockerStrategy |
      | type: Docker   |

  # @author cryan@redhat.com
  # @case_id 517670
  Scenario: Using a docker image as source input using new-build cmd
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-rhel7.json |
      | n | <%= project.name %> |
    Given the "python" image stream was created
    And the "python" image stream becomes ready
    When I run the :new_build client command with:
      | app_repo | openshift/ruby:latest |
      | app_repo | https://github.com/openshift/ruby-hello-world |
      | source_image | <%= project.name %>/python:latest |
      | source_image_path | /tmp:xiuwangtest/ |
      | name | final-app |
      | allow_missing_imagestream_tags| true |
    Then the step should succeed
    When I run the :get client command with:
      | resource | buildconfig |
      | resource_name | final-app |
      | o | yaml |
    Then the output should match:
      | kind:\s+ImageStreamTag |
      | name:\s+python:latest |
      | destinationDir:\s+xiuwangtest |
      | sourcePath:\s+/tmp |
    Given the "final-app-1" build completes
    Given I get project builds
    #Create a deploymentconfig to generate pods to test on,
    #Avoids the use of direct docker commands.
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc517670/dc.json"
    Then the step should succeed
    Given I replace lines in "dc.json":
      | replaceme | final-app |
    Given I replace lines in "dc.json":
      | origin-ruby22-sample | final-app |
    When I run the :create client command with:
      | f | dc.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=frontend |
    When I execute on the "<%= pod.name %>" pod:
      | ls | -al | xiuwangtest |
    Then the output should contain "tmp"
    Given I replace resource "buildconfig" named "final-app" saving edit to "edit_bldcfg.json":
      | destinationDir: xiuwangtest/ | destinationDir: test/ |
    When I run the :start_build client command with:
      | buildconfig | final-app |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=frontend-2 |
    When I execute on the "<%= pod.name %>" pod:
      | ls | -al | test |
    Then the output should contain "tmp"
    Then I run the :import_image client command with:
      | image_name | python |
      | all | true |
      | confirm | true |
      | from | docker.io/openshift/python-33-centos7 |
      | n | <%= project.name %> |
    Then the step should succeed
    Given I get project builds
    Then the output should contain "final-app-3"

  # @author cryan@redhat.com
  # @case_id 519259
  Scenario: Cannot create secret from local file and with same name via oc new-build
    Given I have a project
    #Reusing similar secrets to TC #519256
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc519256/testsecret1.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc519256/testsecret2.json |
    Then the step should succeed
    When I run the :new_build client command with:
      | image_stream | ruby:2.2 |
      | app_repo | https://github.com/openshift-qe/build-secret.git |
      | build_secret | /local/src/file:/destination/dir |
    Then the step should fail
    And the output should contain "must be valid secret"
    When I run the :new_build client command with:
      | image_stream | ruby:2.2 |
      | app_repo | https://github.com/openshift-qe/build-secret.git |
      | strategy | docker |
      | build_secret | testsecret1:/tmp/mysecret |
      | build_secret | testsecret2 |
    Then the step should fail
    And the output should contain "must be a relative path"

  # @author cryan@redhat.com
  # @case_id 517669
  Scenario: Using a docker image as source input for new-build cmd--negetive test
    Given I have a project
    When I run the :new_build client command with:
      | app_repo | openshift/ruby:latest |
      | app_repo | https://github.com/openshift/ruby-hello-world |
      | source_image | openshift/jenkins:latest |
      | source_image_path | src/:/destination-dir |
      | name | app1 |
    Then the step should fail
    And the output should contain "relative path"
    When I run the :new_build client command with:
      | app_repo | openshift/ruby:latest |
      | app_repo | https://github.com/openshift/ruby-hello-world |
      | source_image | openshift/jenkins:latest |
      | source_image_path | /non-existing-source/:destination-dir  |
      | name | app2 |
    Then the step should succeed
    Given the "app2-1" build finishes
    When I run the :logs client command with:
      | resource_name | build/app2-1 |
    Then the output should contain "no such file or directory"
    When I run the :new_build client command with:
      | app_repo | openshift/ruby:latest |
      | app_repo | https://github.com/openshift/ruby-hello-world |
      | source_image | openshift/jenkins:latest |
      | source_image_path | /opt/openshift:Dockerfile |
      | name | app3 |
    Then the step should succeed
    Given the "app3-1" build finishes
    When I run the :logs client command with:
      | resource_name | build/app3-1 |
    Then the output should contain "must be a directory"
    When I run the :new_build client command with:
      | app_repo | openshift/ruby:latest |
      | app_repo | https://github.com/openshift/ruby-hello-world |
      | source_image_path | /source-dir/:destiontion-dir/ |
      | name | app4 |
    Then the step should fail
    And the output should contain "source-image must be specified"
    When I run the :new_build client command with:
      | app_repo | openshift/ruby:latest |
      | app_repo | https://github.com/openshift/ruby-hello-world |
      | source_image | openshift/jenkins:latest |
      | name | app5 |
    Then the step should fail
    And the output should contain "source-image-path must be specified"
    When I run the :new_build client command with:
      | app_repo | openshift/ruby:latest |
      | app_repo | https://github.com/openshift/ruby-hello-world |
      | source_image | openshift/jenkins:latest |
      | source_image_path ||
      | name | app6 |
    Then the step should fail
    And the output should contain "source-image-path must be specified"

  # @author cryan@redhat.com
  # @case_id 521601
  Scenario: Overriding builder image scripts by url scripts in buildConfig under proxy
    Given I have a project
    #Create the proxy
    When I run the :new_build client command with:
      | code | https://github.com/openshift-qe/docker-squid |
      | strategy | docker |
      | to | myappis |
      | name | myapp |
    Then the step should succeed
    Given the "myapp-1" build completes
    When I run the :new_app client command with:
      | image_stream | myappis |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=myappis-1 |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/test-buildconfig.json |
    Then the step should succeed
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby-sample-build |
      | p | {"spec": {"strategy": {"sourceStrategy": {"scripts": "https://raw.githubusercontent.com/openshift-qe/builderimage-scripts/master/bin"}}}} |
    Then the step should succeed
    #Get the proxy ip
    And evaluation of `service("myappis").ip(user: user)` is stored in the :service_ip clipboard
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby-sample-build |
      | p | {"spec": {"strategy": {"sourceStrategy": {"env": [{"name": "http_proxy","value": "http://<%= cb.service_ip %>:3128"}]}}}} |
    Then the step should succeed
    When I run the :get client command with:
      | resource | buildconfig |
      | resource_name | ruby-sample-build |
      | o | json |
    Then the output should contain "http://<%= cb.service_ip %>:3128"
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    Given the "ruby-sample-build-2" build completes

  # @author xiuwang@redhat.com
  # @case_id 519264
  Scenario: Can't allocate out of limits resources to container which builder pod launched for s2i build
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-sti.json |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | buildconfig         |
      | resource_name | ruby22-sample-build |
      | p | {"spec":{"resources": {"requests": {"cpu": "600m","memory": "200Mi"},"limits": {"cpu": "800m","memory": "200Mi"}}}} |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | buildconfig         |
      | resource_name | ruby22-sample-build |
      | p | {"spec": {"source": {"git": {"uri": "git://github.com/openshift-qe/ruby-cgroup-test.git","ref":"memlarge"}}}} |
    Then the step should succeed
    Then I run the :delete client command with:
      | object_type       | builds                |
      | object_name_or_id | ruby22-sample-build-1 |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
      | follow   | true |
      | wait     | true |
      | _timeout | 120  |
    And the output should contain:
      | stress: FAIL                                    |
      | cat /sys/fs/cgroup/memory/memory.limit_in_bytes |
      | 209715200                                       |
    When I run the :patch client command with:
      | resource      | buildconfig         |
      | resource_name | ruby22-sample-build |
      | p | {"spec": {"source": {"git": {"uri": "git://github.com/openshift-qe/ruby-cgroup-test.git","ref":"cpularge"}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
      | follow   | true |
      | wait     | true |
      | _timeout | 120  |
    And the output should contain:
      | cat /sys/fs/cgroup/cpuacct,cpu/cpu.shares        |
      | 614                                              |
      | cat /sys/fs/cgroup/cpuacct,cpu/cpu.cfs_period_us |
      | 100000                                           |
      | cat /sys/fs/cgroup/cpuacct,cpu/cpu.cfs_quota_us  |
      | 80000                                            |

  # @author xiuwang@redhat.com
  # @case_id 517668
  Scenario: Using a docker image as source input for docker build
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc517668/ruby22rhel7-template-docker.json |
    Given the "ruby22-sample-build-1" build completes
    When I run the :get client command with:
      | resource      | buildconfig         |
      | resource_name | ruby22-sample-build |
      | o             | yaml                |
    Then the output should contain "xiuwangtest"
    Given 2 pods become ready with labels:
      | deployment=frontend-1 |
    When I execute on the "<%= pod.name %>" pod:
      | ls |
    Then the step should succeed
    And the output should contain "xiuwangtest"

  # @author xiuwang@redhat.com
  # @case_id 519265
  Scenario: Check cgroup info in container which builder pod launched for docker build
    Given I have a project
    When I run the :new_app client command with:
      | code | https://github.com/openshift-qe/ruby-cgroup-test | 
    Then the step should succeed
    And the "ruby-cgroup-test-1" build was created
    Given the "ruby-cgroup-test-1" build completed
    When I run the :build_logs client command with:
      | build_name  | ruby-cgroup-test-1 |
    And the output should contain:
      | RUN cp -r /sys/fs/cgroup/cpuacct,cpu/cpu* /tmp                     |
      | RUN cp -r /sys/fs/cgroup/memory/memory.limit_in_bytes /tmp/memlimit|
    Given I wait for the "ruby-cgroup-test" service to become ready
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | bash | -c | cat /tmp/memlimit /tmp/cpu.shares /tmp/cpu.cfs_period_us /tmp/cpu.cfs_quota_us |
    Then the step should succeed
    """
    And the output should contain:
      |92233720369152|
      |2             |
      |100000        |
      |-1            |

  # @author haowang@redhat.com
  # @case_id 512264
  Scenario: oc start-build with a local git repo and commit using sti build type
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | https://github.com/openshift/nodejs-ex |
    Then the step should succeed
    And the "nodejs-ex-1" build completed
    Given I wait for the "nodejs-ex" service to become ready
    When I expose the "nodejs-ex" service
    Then I wait for a web server to become available via the "nodejs-ex" route
    And the output should contain "Welcome to OpenShift"
    And I git clone the repo "https://github.com/openshift/nodejs-ex"
    And I run the :start_build client command with:
      | buildconfig | nodejs-ex |
      | from_repo   | nodejs-ex |
    Then the step should succeed
    And the "nodejs-ex-2" build completed
    Given 1 pods become ready with labels:
      | app=nodejs-ex              |
      | deployment=nodejs-ex-2     |
    Then I wait for a web server to become available via the "nodejs-ex" route
    And the output should contain "Welcome to OpenShift"
    Given I replace lines in "nodejs-ex/views/index.html":
      | Welcome to OpenShift | Welcome all to OpenShift |
    Then the step should succeed
    And I commit all changes in repo "nodejs-ex" with message "update index.html"
    Then I get the latest git commit id from repo "nodejs-ex"
    When I run the :start_build client command with:
      | buildconfig | nodejs-ex|
      | from_repo   | nodejs-ex|
      | commit      | <%= cb.git_commit_id %> |
    Then the step should succeed
    And the "nodejs-ex-3" build completed
    Given 1 pods become ready with labels:
      | app=nodejs-ex              |
      | deployment=nodejs-ex-3     |
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | cat                       |
      | views/index.html          |
    And the output should contain "Welcome all to OpenShift"
    """
    When I run the :start_build client command with:
      | buildconfig | nodejs-ex|
      | from_repo   | nodejs-ex|
      | commit      | fffffffffffffffffffffffffffffffffffff |
    Then the step should fail
    When I run the :start_build client command with:
      | buildconfig | nodejs-ex|
      | from_repo   | no-exit  |
      | commit      | <%= cb.git_commit_id %> |
    Then the step should fail

  # @author haowang@redhat.com
  # @case_id 512265
  Scenario: oc start-build with a local git repo and commit using sti build type, with context-dir
    Given I have a project
    When I run the :new_app client command with:
      | app_repo    | https://github.com/openshift/sti-nodejs.git |
      | context_dir | 0.10/test/test-app                          |
    Then the step should succeed
    And the "sti-nodejs-1" build completed
    Given I wait for the "sti-nodejs" service to become ready
    When I expose the "sti-nodejs" service
    Then I wait for a web server to become available via the "sti-nodejs" route
    And the output should contain "This is a node.js echo service"
    And I git clone the repo "https://github.com/openshift/sti-nodejs"
    And I run the :start_build client command with:
      | buildconfig | sti-nodejs |
      | from_repo   | sti-nodejs |
    Then the step should succeed
    And the "sti-nodejs-2" build completed
    Given 1 pods become ready with labels:
      | app=sti-nodejs              |
      | deployment=sti-nodejs-2     |
    Then I wait for a web server to become available via the "sti-nodejs" route
    And the output should contain "This is a node.js echo service"
    Given I replace lines in "sti-nodejs/0.10/test/test-app/server.js":
      | This is a node.js echo service | Welcome to OpenShift  |
    Then the step should succeed
    And I commit all changes in repo "sti-nodejs" with message "update server.js"
    Then I get the latest git commit id from repo "sti-nodejs"
    When I run the :start_build client command with:
      | buildconfig | sti-nodejs|
      | from_repo   | sti-nodejs|
      | commit      | <%= cb.git_commit_id %> |
    Then the step should succeed
    And the "sti-nodejs-3" build completed
    Given 1 pods become ready with labels:
      | app=sti-nodejs              |
      | deployment=sti-nodejs-3     |
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | cat                       |
      | server.js        |
    And the output should contain "Welcome to OpenShift"
    """
    When I run the :start_build client command with:
      | buildconfig | sti-nodejs|
      | from_repo   | sti-nodejs|
      | commit      | fffffffffffffffffffffffffffffffffffff |
    Then the step should fail
    When I run the :start_build client command with:
      | buildconfig | sti-nodejs|
      | from_repo   | no-exit  |
      | commit      | <%= cb.git_commit_id %> |
    Then the step should fail

  # @author haowang@redhat.com
  # @case_id 512263
  Scenario: oc start-build with a local git repo and commit using Docker build type
    Given I have a project
    When I run the :new_app client command with:
      | app_repo    | https://github.com/openshift/ruby-hello-world |
      | strategy    | docker                          |
    Then the step should succeed
    And the "ruby-hello-world-1" build completed
    Given I wait for the "ruby-hello-world" service to become ready
    When I expose the "ruby-hello-world" service
    Then I wait for a web server to become available via the "ruby-hello-world" route
    And the output should contain "Welcome to an OpenShift v3 Demo App!"
    And I git clone the repo "https://github.com/openshift/ruby-hello-world"
    And I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
      | from_repo   | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-2" build completed
    Given 1 pods become ready with labels:
      | app=ruby-hello-world              |
      | deployment=ruby-hello-world-2     |
    Then I wait for a web server to become available via the "ruby-hello-world" route
    And the output should contain "Welcome to an OpenShift v3 Demo App!"
    Given I replace lines in "ruby-hello-world/views/main.erb":
      | Welcome to an OpenShift v3 Demo App! | Welcome all to an OpenShift v3 Demo App!  |
    Then the step should succeed
    And I commit all changes in repo "ruby-hello-world" with message "update server.js"
    Then I get the latest git commit id from repo "ruby-hello-world"
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world|
      | from_repo   | ruby-hello-world|
      | commit      | <%= cb.git_commit_id %> |
    Then the step should succeed
    And the "ruby-hello-world-3" build completed
    Given 1 pods become ready with labels:
      | app=ruby-hello-world              |
      | deployment=ruby-hello-world-3     |
    And I wait up to 20 seconds for the steps to pass:
    """
    When I execute on the pod:
      | cat                       |
      | views/main.erb            |
    And the output should contain "Welcome all to an OpenShift v3 Demo App!"
    """
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world|
      | from_repo   | ruby-hello-world|
      | commit      | fffffffffffffffffffffffffffffffffffff |
    Then the step should fail
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world|
      | from_repo   | no-exit  |
      | commit      | <%= cb.git_commit_id %> |
    Then the step should fail

  # @author yantan@redhat.com
  # @case_id 483593
  Scenario: Sync pod status after delete its related build
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/php-56-rhel7-stibuild.json |
    Then the step should succeed
    Given the "php-sample-build-1" build becomes :pending
    When I run the :delete client command with:
      | object_type | build |
      | object_name_or_id| php-sample-build-1 |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I get project pods
    Then the step should succeed
    And the output should not contain "php"
    """
    And I wait for the steps to pass:
    """
    When I get project replicationcontroller
    Then the output should not contain "frontend"
    """
    When I run the :start_build client command with:
      | buildconfig | php-sample-build |
    Given the "php-sample-build-2" build becomes :running
    When I get project pods
    Then the output should contain "php"
    When I run the :delete client command with:
      | object_type | build|
      | object_name_or_id | php-sample-build-2 |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I get project pods
    Then the step should succeed
    And the output should not contain "php"
    """
    When I run the :start_build client command with:
       | buildconfig | php-sample-build |
    Given the "php-sample-build-3" build becomes :complete
    Given the pod named "php-sample-build-3-build" status becomes :succeeded
    When I get project pods
    Then the output should contain "php"
    When I run the :delete client command with:
       | object_type | build |
       | object_name_or_id | php-sample-build-3 |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I get project pods
    Then the output should not contain "php"
    """
    When I replace resource "bc" named "php-sample-build":
      | https://github.com/openshift-qe/php-example-app | https://github.com/openshift-qe/php-example-apptest |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | php-sample-build |
    Given the "php-sample-build-4" build becomes :failed
    When I get project pods
    Then the output should contain "php"
    When I run the :delete client command with:
      | object_type | build |
      | object_name_or_id |  php-sample-build-4|
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I get project pods
    Then the output should not contain "php"
    """

  # @author cryan@redhat.com
  # @case_id 525734
  Scenario: Cannot docker build with no inputs in buildconfig
    Given I have a project
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/nosrc-extended-test-bldr/master/nosrc-test.json"
    When I run the :create client command with:
      | f | nosrc-test.json |
    Then the step should fail
    And the output should contain "must provide a value"
    Given I replace lines in "nosrc-test.json":
      | "source": {}, | "source": { "type": "None" }, |
    When I run the :create client command with:
      | f | nosrc-test.json |
    Then the step should fail
    And the output should contain "must provide a value"

  # @author yantan@redhat.com
  # @case_id 525736
  Scenario: Do sti build with no inputs in buildconfig
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/nosrc-extended-test-bldr/master/nosrc-setup.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/nosrc-extended-test-bldr/master/nosrc-test.json  |
    When I run the :get client command with:
      | resource | bc |
    Then the output should contain:
      | ruby-sample-build-ns |
    When I run the :start_build client command with:
      | buildconfig | nosrc-bldr |
    Then the step should succeed
    Given the "nosrc-bldr-1" build becomes :complete
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build-ns |
    Given the "ruby-sample-build-ns-1" build becomes :complete
    When I run the :delete client command with:
      | object_type      | bc |
      | object_name_or_id | ruby-sample-build-ns |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc525736/Nonesrc-sti.json |
    When I run the :get client command with:
      | resource      | bc |
      | resource_name | ruby-sample-build-ns |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build-ns |
    Then the step should succeed
    Given the "ruby-sample-build-ns-1" build becomes :complete
