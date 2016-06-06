Feature: Configuration of environment variables check

  # @author xiuwang@redhat.com
  # @case_id 499488 499490
  Scenario Outline: Check environment variables of ruby-20 image
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-<os>.json |
      | n | <%= project.name %> |
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-env-sti.json |
    Then the step should succeed
    Given I wait for the "frontend" service to become ready
    When I run the :describe client command with:
      | resource | build |
      | name | ruby-sample-build-1 |
    Then the step should succeed
    And the output should contain "<image>"
    When I execute on the pod:
      | env |
    Then the step should succeed
    And the output should contain:
      | RACK_ENV=production            |
      | RAILS_ENV=production           |
      | DISABLE_ASSET_COMPILATION=true |
    Examples:
      | os | image |
      | rhel7   | <%= product_docker_repo %>openshift3/ruby-20-rhel7:latest |
    #| centos7 | docker.io/openshift/ruby-20-centos7 |

  # @author xiuwang@redhat.com
  # @case_id 499491
  Scenario: Check environment variables of perl-516-rhel7 image
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/perl516rhel7-env-sti.json |
    Then the step should succeed
    Given I wait for the "frontend" service to become ready
    When I execute on the pod:
      | env |
    Then the step should succeed
    And the output should contain:
      | ENABLE_CPAN_TEST=on |
      | CPAN_MIRROR=        |

  # @author wzheng@redhat.com
  # @case_id 499485
  Scenario: Configuration of enviroment variables check - php-55-rhel7
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/php-55-rhel7-stibuild.json |
    Then the step should succeed
    Given the "php-sample-build-1" build was created
    Given the "php-sample-build-1" build completed
    Given I wait for the "frontend" service to become ready
    When I execute on the pod:
      | env |
    Then the step should succeed
    And the output should contain:
      | ERROR_REPORTING=E_ALL & ~E_NOTICE |
      | DISPLAY_ERRORS=ON |
      | DISPLAY_STARTUP_ERRORS=OFF |
      | TRACK_ERRORS=OFF |
      | HTML_ERRORS=ON |
      | INCLUDE_PATH=/opt/app-root/src |
      | SESSION_PATH=/tmp/sessions |
      | OPCACHE_MEMORY_CONSUMPTION=16M |
      | PHPRC=/opt/rh/php55/root/etc/ |
      | PHP_INI_SCAN_DIR=/opt/rh/php55/root/etc/ |

  # @author cryan@redhat.com
  # @case_id 493677
  Scenario: Substitute environment variables into a container's command
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/container/commandtest.json |
    Then the step should succeed
    Given the pod named "expansion-pod" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | expansion-pod |
    Then the step should succeed
    And the output should contain "http"

  # @author pruan@redhat.com
  # @case_id 493676
  Scenario: Substitute environment variables into a container's args
    Given I have a project
    When I run the :create client command with:
      | f |  https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/container/argstest.json |
    Then the step should succeed
    Given the pod named "expansion-pod" status becomes :running
    When I run the :logs client command with:
      | resource_name | expansion-pod |
    Then the step should succeed
    And the output should contain:
      |  serving on 8080 |
      |  serving on 8888 |

  # @author pruan@redhat.com
  # @case_id 493678
  Scenario: Substitute environment variables into a container's env
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc493678/envtest.json |
    Then the step should succeed
    Given the pod named "hello-openshift" status becomes :running
    When I run the :env client command with:
      | resource | pod             |
      | keyval   | hello-openshift |
      | list     | true            |
    Then the step should succeed
    And the output should match:
      | zzhao=redhat                    |
      | test2=\$\(zzhao\)               |
      | test3=___\$\(zzhao\)___         |
      | test4=\$\$\(zzhao\)_\$\(test2\) |
      | test6=\$\(zzhao\$\(zzhao\)      |
      | test7=\$\$\$\$\$\$\(zzhao\)     |
      | test8=\$\$\$\$\$\$\$\(zzhao\)   |

  # @author cryan@redhat.com haowang@redhat.com
  # @case_id 521464 521463
  Scenario Outline: Users can override the the env tuned by ruby base image
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | <imagestream>~https://github.com/openshift/rails-ex |
    Then the step should succeed
    Given 1 pods become ready with labels:
      | app=rails-ex |
    When I run the :env client command with:
      | resource | dc/rails-ex |
      | e | PUMA_MIN_THREADS=1,PUMA_MAX_THREADS=14,PUMA_WORKERS=5 |
    Given 1 pods become ready with labels:
      | deployment=rails-ex-2 |
    When I run the :logs client command with:
      | resource_name | pod/<%= pod.name %>|
    Then the output should contain:
      | Min threads: 1     |
      | max threads: 14    |
      | Process workers: 5 |

    Examples:
      | imagestream |
      | openshift/ruby:2.0 |
      | openshift/ruby:2.2 |
