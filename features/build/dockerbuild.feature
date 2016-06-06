Feature: dockerbuild.feature
  # @author wzheng@redhat.com
  # @case_id 470418
  Scenario: Docker build with blank source repo
    Given I have a project
    When I run the :process client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-docker-blankrepo.json |
    Then the step should succeed
    Given I save the output to file>blankrepo.json
    When I run the :create client command with:
      | f | blankrepo.json |
    Then the step should fail
    Then the output should contain "spec.source.git.uri: Required value"

  # @author wzheng@redhat.com
  # @case_id 470419
  Scenario: Push build with invalid github repo
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-sti-invalidrepo.json |
    Then the step should succeed
    When I run the :new_app client command with:
      | template | ruby-helloworld-sample |
    Then the step should succeed
    And the "ruby22-sample-build-1" build was created
    And the "ruby22-sample-build-1" build failed
    When I run the :logs client command with:
      | resource_name | bc/ruby22-sample-build |
    Then the output should contain "Invalid git source url: 123"

  # @author wzheng@redhat.com
  # @case_id 438849
  Scenario: Docker build with both SourceURI and context dir
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-context-docker.json |
    Then the step should succeed
    When I run the :new_app client command with:
      | template | ruby-helloworld-sample |
    Then the step should succeed
    And the "ruby20-sample-build-1" build was created
    And the "ruby20-sample-build-1" build completed
    When I run the :describe client command with:
      | resource | buildconfig         |
      | name     | ruby20-sample-build |
    Then the step should succeed
    And the output should contain "ContextDir:"

  # @author wzheng@redhat.com
  # @case_id 438850
  Scenario: Docker build with invalid context dir
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-invalidcontext-docker.json |
    Then the step should succeed
    When I run the :new_app client command with:
      | template | ruby-helloworld-sample |
    Then the step should succeed
    And the "ruby20-sample-build-1" build was created
    And the "ruby20-sample-build-1" build failed
    When I run the :logs client command with:
      | resource_name| bc/ruby20-sample-build |
    Then the output should contain "/invalid/Dockerfile: no such file or directory"

  # @author haowang@redhat.com
  # @case_id 507555
  Scenario: Add empty ENV to DockerStrategy buildConfig when do docker build
    Given I have a project
    When I run the :new_app client command with:
      | file |  https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/application-template-dockerbuild-blankvar.json |
    Then the step should fail
    And the output should contain "invalid"

  # @author cryan@redhat.com
  # @case_id 512262
  Scenario: oc start-build with a file passed,sti build type
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | https://github.com/openshift/nodejs-ex |
    Then the step should succeed
    Given the "nodejs-ex-1" build completed
    Given I download a file from "https://raw.githubusercontent.com/openshift/nodejs-ex/master/package.json"
    When I run the :start_build client command with:
      | buildconfig | nodejs-ex |
      | from_file | package.json |
    Then the step should succeed
    Given the "nodejs-ex-2" build completed
    When I run the :start_build client command with:
      | buildconfig | nodejs-ex |
      | from_file | nonexist.json |
    Then the step should fail
    And the output should contain "no such file"
  # @author yantan@redhat.com
  # @case_id 479296
  Scenario: Custom build with dockerImage with specified tag
    Given I have a project
    Then the step should succeed
    And I process and create:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc479296/application-template-custombuild.json |
    Then the step should succeed
    And I run the :describe client command with:
      | resource | buildconfig |
      | name | ruby-sample-build |
    Then the step should succeed
    And the output should contain:
      |DockerImage openshift/origin-custom-docker-builder:latest|
    And I run the :get client command with:
      | resource | builds |
    Then the step should succeed
    And I run the :describe client command with:
      | resource | builds|
    Then the step should succeed
    Then the output should contain:
      |DockerImage openshift/origin-custom-docker-builder:latest|
    When I replace resource "bc" named "ruby-sample-build":
      | openshift/origin-custom-docker-builder:latest  | openshift/origin-custom-docker-builder:a2aa234 |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :logs client command with:
      | resource_name | bc/ruby-sample-build |
    And the output should contain:
      | timed out |

  # @author dyan@redhat.com
  # @case_id 479297, 482273
  Scenario Outline: Docker and STI build with dockerImage with specified tag
    Given I have a project
    When I run oc create over "<template>" replacing paths:
      | ["spec"]["strategy"]["<strategy>"]["from"]["name"] | <%= product_docker_repo %>rhscl/ruby-22-rhel7:latest |
    Then the step should succeed
    Given the "ruby-sample-build-1" build completed
    When I run the :describe client command with:
      | resource | build |
      | name | ruby-sample-build-1 |
    Then the output should contain:
      | DockerImage <%= product_docker_repo %>rhscl/ruby-22-rhel7:latest |
    When I run the :patch client command with:
      | resource      | bc              |
      | resource_name | ruby-sample-build |
      | p             | {"spec":{"strategy":{"<strategy>":{"from":{"name":"<%= product_docker_repo %>rhscl/ruby-22-rhel7:incorrect"}}}}} |
    Then the step should succeed
    Given I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    And the "ruby-sample-build-2" build failed
    When I run the :describe client command with:
      | resource | build |
      | name | ruby-sample-build-2 |
    Then the output should contain:
      | Failed |
      | DockerImage <%= product_docker_repo %>rhscl/ruby-22-rhel7:incorrect |

    Examples:
      | template | strategy |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc479297/test-template-dockerbuild.json | dockerStrategy |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc482273/test-template-stibuild.json    | sourceStrategy |

  # @author dyan@redhat.com
  # @case_id 519484
  Scenario: Implement post-build command for docker build
    Given I have a project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc479297/test-template-dockerbuild.json" replacing paths:
      | ["spec"]["strategy"]["dockerStrategy"]["from"]["name"] | <%= product_docker_repo %>rhscl/ruby-22-rhel7:latest |
      | ["spec"]["postCommit"]                                 | {"script":"bundle exec rake test"}                   |
    Then the step should succeed
    Given the "ruby-sample-build-1" build completed
    When I run the :logs client command with:
      | resource_name | build/ruby-sample-build-1 |
    Then the output should contain:
      | 1 runs, 1 assertions, 0 failures, 0 errors, 0 skips |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc479297/test-template-dockerbuild.json" replacing paths:
      | ["metadata"]["name"]                                   | ruby-sample-build2 |
      | ["spec"]["strategy"]["dockerStrategy"]["from"]["name"] | <%= product_docker_repo %>rhscl/ruby-22-rhel7:latest |
      | ["spec"]["postCommit"]                                 | {"command":["/bin/bash","-c","bundle exec rake test --verbose"]} |
    Then the step should succeed
    And the "ruby-sample-build2-1" build completed
    When I run the :logs client command with:
      | resource_name | build/ruby-sample-build2-1 |
    Then the output should contain:
      | 1 runs, 1 assertions, 0 failures, 0 errors, 0 skips |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc479297/test-template-dockerbuild.json" replacing paths:
      | ["metadata"]["name"]                                   | ruby-sample-build3 |
      | ["spec"]["strategy"]["dockerStrategy"]["from"]["name"] | <%= product_docker_repo %>rhscl/ruby-22-rhel7:latest |
      | ["spec"]["postCommit"]                                 | {"args":["bundle","exec","rake","test","--verbose"]} |
    Then the step should succeed
    And the "ruby-sample-build3-1" build completed
    When I run the :logs client command with:
      | resource_name | build/ruby-sample-build3-1 |
    Then the output should contain:
      | 1 runs, 1 assertions, 0 failures, 0 errors, 0 skips |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc479297/test-template-dockerbuild.json" replacing paths:
      | ["metadata"]["name"]                                   | ruby-sample-build4 |
      | ["spec"]["strategy"]["dockerStrategy"]["from"]["name"] | <%= product_docker_repo %>rhscl/ruby-22-rhel7:latest |
      | ["spec"]["postCommit"]                                 | {"args":["--verbose"],"script":"bundle exec rake test $1"} |
    Then the step should succeed
    And the "ruby-sample-build4-1" build completed
    When I run the :logs client command with:
      | resource_name | build/ruby-sample-build4-1 |
    Then the output should contain:
      | 1 runs, 1 assertions, 0 failures, 0 errors, 0 skips |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc479297/test-template-dockerbuild.json" replacing paths:
      | ["metadata"]["name"]                                   | ruby-sample-build5 |
      | ["spec"]["strategy"]["dockerStrategy"]["from"]["name"] | <%= product_docker_repo %>rhscl/ruby-22-rhel7:latest |
      | ["spec"]["postCommit"]                                 | {"command":["/bin/bash","-c","bundle exec rake test"],"args":["--verbose"]} |
    Then the step should succeed
    And the "ruby-sample-build5-1" build completed
    When I run the :logs client command with:
      | resource_name | build/ruby-sample-build5-1 |
    Then the output should contain:
      | 1 runs, 1 assertions, 0 failures, 0 errors, 0 skips |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc479297/test-template-dockerbuild.json" replacing paths:
      | ["metadata"]["name"]                                   | ruby-sample-build6 |
      | ["spec"]["strategy"]["dockerStrategy"]["from"]["name"] | <%= product_docker_repo %>rhscl/ruby-22-rhel7:latest |
      | ["spec"]["postCommit"]                                 | {"script":"bundle exec rake1 test --verbose"} |
    Then the step should succeed
    And the "ruby-sample-build6-1" build failed
    When I run the :logs client command with:
      | resource_name | build/ruby-sample-build6-1 |
    Then the output should contain:
      | bundler: command not found: rake1 |

  # @author wewang@redhat.com
  # @case_id 517672
  @admin
  @destructive
  Scenario: Edit bc with an allowed strategy to use a restricted strategy
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-sti.json |
    Then the step should succeed
    Given I switch to the second user
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-docker.json |
    Then the step should succeed
    And the "ruby22-sample-build-1" build was created
    Given cluster role "system:build-strategy-docker" is removed from the "system:authenticated" group
    When I run the :get client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | o | json |
    Then the step should succeed
    Given I save the output to file>bc.json
    And I replace lines in "bc.json":
      | Docker | Source |
      |dockerStrategy|sourceStrategy|
    When I run the :replace client command with:
      | f | bc.json |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    Then the "ruby22-sample-build-2" build was created

    Given I switch to the first user
    When I run the :get client command with:
      | resource | buildconfig |
      | resource_name | ruby22-sample-build |
      | o | json |
    Then the step should succeed
    Given I save the output to file>bc1.json
    And I replace lines in "bc1.json":
      | Source | Docker  |
      | sourceStrategy|dockerStrategy|
    When I run the :replace client command with:
      | f | bc1.json |
    Then the step should fail
    And the output should contain "build strategy Docker is not allowed"

  # @author wewang@redhat.com
  # @case_id 517672
  @admin
  @destructive
  Scenario: Allowing only certain users in a specific project to create builds with a particular strategy
    Given I have a project
    Given cluster role "system:build-strategy-docker" is removed from the "system:authenticated" group
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-docker.json |
    Then the step should fail
    And the output should contain "build strategy Docker is not allowed"
    Given I create a new project
    And evaluation of `project.name` is stored in the :proj_name clipboard
    When I run the :policy_add_role_to_user admin command with:
      | role            |   system:build-strategy-docker |
      | user name       |   <%= user.name %>    |
      | n               |   <%= cb.proj_name %> |
    Then the step should succeed
    And I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-docker.json |
    Then the step should succeed
    And the "ruby22-sample-build-1" build was created
    Given I create a new project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-docker.json |
    Then the step should fail
    And the output should contain "build strategy Docker is not allowed"

