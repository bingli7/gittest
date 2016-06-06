Feature: security.feature

  # @author haowang@redhat.com
  # @case_id 526562
  Scenario: normal user cannot update the build pod image
    Given I have a project
    When I run the :new_app client command with:
      | app_repo | openshift/ruby:2.2~https://github.com/openshift/ruby-hello-world.git |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    And the pod named "ruby-hello-world-1-build" is present
    When I run the :patch client command with:
      | resource      | pod                      |
      | resource_name | ruby-hello-world-1-build |
      | p             | {"spec":{"containers":[{"name":"sti-build","image":"test/destructiveimage"}]}}|
    Then the step should fail
    And the output should contain:
      | unable to validate |
    Given the "ruby-hello-world-1" build becomes :running
    When I run the :rsh client command with:
      | pod  | ruby-hello-world-1-build |
      | command | echo ""               |
    Then the step should fail
    And the output should contain:
      | unable to validate |
