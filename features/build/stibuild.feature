Feature: stibuild.feature
  # @author haowang@redhat.com
  # @case_id 476410
  Scenario: STI build with SourceURI and context dir
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/python-27-rhel7-context-stibuild.json |
    Then the step should succeed
    And the "python-sample-build-1" build was created
    And the "python-sample-build-1" build completed

  # @author wzheng@redhat.com
  # @case_id 479021
  Scenario: Add ENV to STIStrategy buildConfig when do sti build
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-env-sti.json |
    Then the step should succeed
    And the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completed
    Given I wait for the "frontend" service to become ready
    When I run the :env client command with:
      | resource | pods |
      | list     | true |
      | all      | true |
    Then the step should succeed
    And the output should contain:
      | {"name":"DISABLE_ASSET_COMPILATION","value":"true"}]}} |
    When I run the :get client command with:
      | resource | buildconfig |
      | resource_name | ruby-sample-build |
      | o | json |
    And I save the output to file>bc.json
    And I replace lines in "bc.json":
      | true | 1 |
    When I run the :replace client command with:
      | f | bc.json |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    And the "ruby-sample-build-2" build was created
    And the "ruby-sample-build-2" build completed
    Given I wait for the "frontend" service to become ready
    When I run the :env client command with:
      | resource | pods |
      | list     | true |
      | all      | true |
    Then the step should succeed
    And the output should contain:
      | {"name":"DISABLE_ASSET_COMPILATION","value":"1"}]}} |

  # @author haowang@redhat.com
  # @case_id 476409
  Scenario: STI build with invalid context dir
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/python-27-rhel7-errordir-stibuild.json |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | python-sample-build |
    And the "python-sample-build-1" build was created
    And the "python-sample-build-1" build failed
    When I run the :logs client command with:
      | resource_name | python-sample-build-1-build |
    And the output should contain "no such file or directory"

  # @author wzheng@redhat.com
  # @case_id 497874
  Scenario: Build invoked once buildconfig is created when there is no imagechangetrigger in buildconfig
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/stibuild-configchange.json |
    Then the step should succeed
    And the "php-sample-build-1" build was created
    And the "php-sample-build-1" build completed
    When I expose the "frontend" service
    Then I wait for a web server to become available via the "frontend" route
    And the output should contain:
      | Hello World!|
