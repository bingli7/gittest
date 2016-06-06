Feature: buildlogic.feature

  # @author haowang@redhat.com
  # @case_id 515806
  @admin
  Scenario: if build fails to schedule because of quota, after the quota increase, the build should start
    Given I have a project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/quota_pods.yaml |
      | n | <%= project.name %> |
    Then the step should succeed
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/test-buildconfig.json |
    Then the step should succeed
    And the "ruby-sample-build-1" build was created
    When I run the :get client command with:
      | resource | build |
    Then the output should contain:
      |  (CannotCreateBuildPod) |
    When I run the :delete admin command with:
      | object_type       | resourcequota       |
      | object_name_or_id | quota               |
      | n                 | <%= project.name %> |
    Then the step should succeed
    When I run the :get client command with:
      | resource | build |
    Then the output should not contain:
      |  (CannotCreateBuildPod) |

  # @author haowang@redhat.com
  # @case_id 515254
  Scenario: Build with specified Dockerfile via new-build -D
    Given I have a project
    When I run the :new_build client command with:
      | D     | FROM centos:7\nRUN yum install -y httpd              |
      | to    | myappis                                              |
      | name  | myapp                                                |
    Then the step should succeed
    And the "myapp-1" build was created
    And the "myapp-1" build completed

  # @author xiazhao@redhat.com
  # @case_id 501096
  Scenario: Result image will be tried to push after multi-build
    Given I have a project
    When I run the :new_app client command with:
      | file |  https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/php-55-rhel7-stibuild.json |
    Then the step should succeed
    # The 1st build should be triggered automatically
    And the "php-sample-build-1" build was created
    # Trigger the 2nd build in order for doing multi-builds
    When I run the :start_build client command with:
      | buildconfig | php-sample-build |
    Then the step should succeed
    And the "php-sample-build-2" build was created
    # Wait for the first 2 builds finished
    And the "php-sample-build-1" build finished
    And the "php-sample-build-2" build finished
    # Trigger the 3rd build, it should succeed
    When I run the :start_build client command with:
      | buildconfig | php-sample-build |
    Then the step should succeed
    And the "php-sample-build-3" build was created
    And the "php-sample-build-3" build completed
    When I run the :build_logs client command with:
      | build_name  | php-sample-build-3 |
    Then the output should match "Successfully pushed"

  # @author gpei@redhat.com
  # @case_id 515255
  Scenario: Create build without output
    Given I have a project
    When I run the :new_build client command with:
      | app_repo  | openshift/ruby:2.0~https://github.com/openshift/ruby-hello-world.git |
      | no-output | true                                                                 |
      | name      | myapp                                                                |
    Then the step should succeed
    And the "myapp-1" build was created
    And the "myapp-1" build completed
    When I run the :build_logs client command with:
      | build_name | myapp-1 |
    Then the output should contain "Build does not have an Output defined, no output image was pushed to a registry"

  # @author yantan@redhat.com
  # @case_id 520291
  Scenario: Create new build config use dockerfile with source repo
    Given I have a project
    When I run the :new_build client command with:
      | app_repo | https://github.com/openshift/ruby-hello-world |
      | D | FROM centos:7\nRUN yum install -y httpd |
    Then the step should succeed
    When I run the :get client command with:
      | resource | bc |
      | o | yaml |
    Then the step should succeed
    Then the output should contain:
      | dockerfile: |
      |  FROM centos:7 |
      |  RUN yum install -y httpd |
      | git: |
      | uri: https://github.com/openshift/ruby-hello-world |
      | secrets: [] |
      | type: Git |
    When I run the :get client command with:
      | resource | build |
    Then the "ruby-hello-world-1" build completed

  # @author haowang@redhat.com
  # @case_id 499515
  Scenario Outline: Prevent STI builder images from running as root
    Given I have a project
    When I run the :create client command with:
      | f | <template> |
    Then the step should succeed
    Given the "<buildname>" build was created
    And the "<buildname>" build failed
    When I run the :build_logs client command with:
      | build_name  | <buildname> |
    Then the output should match:
      | specify.*user |

    Examples:
      | buildname                       | template                                                                                                               |
      | ruby-sample-build-user0-1       | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc499515/test-buildconfig-user0.json          |
      | ruby-sample-build-userdefault-1 | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc499515/test-buildconfig-userdefault.json    |
      | ruby-sample-build-userroot-1    | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc499515/test-buildconfig-userroot.json       |
      | ruby-sample-build-usernon-1     | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc499515/test-buildconfig-usernon.json        |

  # @author haowang@redhat.com
  # @case_id 499516
  Scenario Outline: Prevent STI builder images from running as root - using onbuild image
    Given I have a project
    When I run the :create client command with:
      | f | <template> |
    Then the step should succeed
    Given the "<buildname>" build was created
    And the "<buildname>" build failed
    When I run the :build_logs client command with:
      | build_name  | <buildname> |
    Then the output should contain:
      |  not allowed |

    Examples:
      | buildname                               | template                                                                                                                   |
      | ruby-sample-build-onbuild-user0-1       | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc499516/test-buildconfig-onbuild-user0.json      |
      | ruby-sample-build-onbuild-userdefault-1 | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc499516/test-buildconfig-onbuild-userdefault.json|

  # @author haowang@redhat.com
  # @case_id 497420 497421 497460 497461
  Scenario Outline: ForcePull image for build
    Given I have a project
    When I run the :create client command with:
      | f | <template> |
    Then the step should succeed
    Given the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build becomes :running
    When I run the :describe client command with:
      | resource | build               |
      | name     | ruby-sample-build-1 |
    Then the step should succeed
    And the output should match:
      | Force Pull:\s+(true\|yes)|
    When I run the :logs client command with:
      | resource_name    | pod/ruby-sample-build-1-build |
    Then the step should succeed
    And the output should contain:
      | "forcePull":true |

    Examples:
      | template                                                                                                                    |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/forcePull/buildconfig-docker-ImageStream.json      |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/forcePull/buildconfig-s2i-ImageStream.json         |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/forcePull/buildconfig-docker-dockerimage.json      |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/forcePull/buildconfig-s2i-dockerimage.json         |

  # @author haowang@redhat.com
  # @case_id 497462 497463
  Scenario Outline: ForcePull image for build using ImageSteamImage
    Given I have a project
    When I run the :get client command with:
      | resource      | istag          |
      | resource_name | ruby:2.2       |
      | o             | json           |
      | n             | openshift      |
    Then the step should succeed
    Given the output is parsed as JSON
    And evaluation of `@result[:parsed]['image']['metadata']['name']` is stored in the :imagestreamimage clipboard
    When I run oc create over "<template>" URL replacing paths:
      | ['spec']['strategy']['<strategy>']['from']['name'] | ruby@<%= cb.imagestreamimage %> |
    Then the step should succeed
    Given the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build becomes :running
    When I run the :describe client command with:
      | resource | build               |
      | name     | ruby-sample-build-1 |
    Then the step should succeed
    And the output should match:
      | Force Pull:\s+(true\|yes)|
    When I run the :logs client command with:
      | resource_name    | pod/ruby-sample-build-1-build |
    Then the step should succeed
    And the output should contain:
      | "forcePull":true |

    Examples:
      | strategy       | template                                                                                                                   |
      | dockerStrategy | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/forcePull/buildconfig-docker-ImageStreamImage.json |
      | sourceStrategy | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/forcePull/buildconfig-s2i-ImageStreamImage.json    |

  # @author yantan@redhat.com
  # @case_id 515252
  Scenario: Build with specified Dockerfile to image with same image name via new-build
    Given I have a project
    When I run the :new_build client command with:
      | D | FROM centos:7\nRUN yum install -y httpd |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | bc     |
      | name     | centos |
    Then the output should contain:
      | From Image:		ImageStreamTag centos:7      |
      | Output to:		ImageStreamTag centos:latest |
    Given the "centos-1" build becomes :complete
    When I run the :new_build client command with:
      | D    | FROM centos:7\nRUN yum install -y httpd |
      | to   | centos:7                                |
      | name | myapp                                   |
    And I run the :get client command with:
      | resource | buildConfig |
    Then the output should contain:
      | myapp |
    Given the "myapp-1" build becomes :complete
    And the "myapp-2" build becomes :complete
    And the "myapp-3" build becomes :running
    When I run the :new_build client command with:
      | code         | https://github.com/openshift/nodejs-ex.git    |
      | image_stream | openshift/nodejs:0.10                         |
      | code         | https://github.com/openshift/ruby-hello-world |
      | image_stream | openshift/ruby:2.0                            |
      | to           | centos:7                                      |
    Then the step should fail
    And the output should contain:
      | error |

  # @author dyan@redhat.com
  # @case_id 476354
  Scenario: Failed to push image with invalid Docker secret
    Given I have a project
    When I run the :oc_secrets_new_dockercfg client command with:
      | secret_name     | pushme |
      | docker_username | dyan |
      | docker_password | xxxxxx |
      | docker_email    | dyan@redhat.com |
    Then the step should succeed
    When I run the :add_secret client command with:
      | sa_name | builder |
      | secret_name | pushme |
    Then the step should succeed
    When I process and create "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/tc476354/pushimage.json"
    Then the step should succeed
    And the "ruby22-sample-build-1" build failed
    When I run the :logs client command with:
      | resource_name | build/ruby22-sample-build-1 |
    Then the output should contain:
      | build error |
      | Failed to push image |
