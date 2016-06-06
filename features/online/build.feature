Feature: ONLY ONLINE related feature's scripts in this file

  # @author bingli@redhat.com
  # @case_id 516510
  Scenario: cli disables Docker builds and custom builds and allow only sti builds
    Given I have a project
    When I run the :new_build client command with:
      | app_repo | centos/ruby-22-centos7~https://github.com/openshift/ruby-hello-world.git |
      | name     | sti-bc    |
    Then the step should succeed
    When I run the :new_build client command with:
      | app_repo | centos/ruby-22-centos7~https://github.com/openshift/ruby-hello-world.git |
      | name     | docker-bc |
      | strategy | docker    |
    Then the step should fail
    And the output should contain:
      | build strategy Docker is not allowed |
    When I process and create "https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-custombuild.json"
    Then the step should fail
    And the output should contain:
      | build strategy Custom is not allowed |
    When I replace resource "bc" named "sti-bc":
      | sourceStrategy | dockerStrategy |
      | type: Source   | type: Docker   |
    Then the step should fail
    And the output should contain:
      | build strategy Docker is not allowed |
