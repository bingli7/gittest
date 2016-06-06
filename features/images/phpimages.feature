Feature: phpimages.feature

  # @author cryan@redhat.com
  # @case_id 499480
  # @bug_id 1253248
  Scenario: session.save_path works well in non privileged mode - php-55-rhel7
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | https://github.com/openshift-qe/ose-php-session |
    Then the step should succeed
    Given the "ose-php-session-1" build completes
    Given 1 pods become ready with labels:
      | app=ose-php-session |
    When I run the :expose client command with:
      | resource | pod |
      | resource_name | <%= pod.name %> |
      | target_port | 8080 |
      | name | myservice |
    Given I wait for the "myservice" service to become ready
    When I execute on the "<%= pod.name %>" pod:
      | curl | -k | <%= service.url %> |
    Then the output should not contain:
      | Warning |
      | Permission |
      | error |

  # @author wzheng@redhat.com
  # @case_id 526520,526521
  Scenario Outline: Update php image to autoconfigure based on available memory
    Given I have a project
    When I run the :create client command with:
      | f |  <template1> |
    Then the step should succeed
    And the "php-app-1" build was created
    And the "php-app-1" build completed
    And a pod becomes ready with labels:
      | app=php-app |
    When I execute on the pod:
      | cat | /opt/app-root/etc/conf.d/50-mpm-tuning.conf |
    Then the output should contain:
      | MaxRequestWorkers     17 |
      | ServerLimit           17 |
    When I delete all resources by labels:
      | app=php-app |
    When I run the :create client command with:
      | f |  <template2> |
    Then the step should succeed
    And the "php-app-1" build was created
    And the "php-app-1" build completed
    And a pod becomes ready with labels:
      | app=php-app |
    When I execute on the pod:
      | cat | /opt/app-root/etc/conf.d/50-mpm-tuning.conf |
    Then the output should contain:
      | MaxRequestWorkers     256 |
      | ServerLimit           256 |
    Examples:
      | template1 | template2|
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/tc526520/php-55-template.json | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/tc526520/php-55-template-noresource.json |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/tc526521/php-56-template.json |  https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/tc526521/php-56-template-noresource.json |
