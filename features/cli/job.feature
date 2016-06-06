Feature: job.feature

  # @author cryan@redhat.com
  # @case_id 511597
  Scenario: Create job with multiple completions
    Given I have a project
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc511597/job.yaml"
    When I run the :create client command with:
      | f | job.yaml |
    Then the step should succeed
    Given 5 pods become ready with labels:
      | app=pi |
    When I run the :get client command with:
      | resource | pods |
      | l | app=pi |
    Then the step should succeed
    And the output should contain 5 times:
      |  pi- |
    Given 5 pods become ready with labels:
      | app=pi |
    Given evaluation of `@pods[0].name` is stored in the :pilog clipboard
    Given the pod named "<%= cb.pilog %>" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | <%= cb.pilog %> |
    Then the step should succeed
    And the output should contain "3.14159"
    When I run the :delete client command with:
      | object_type | job |
      | object_name_or_id | pi |
    Then the step should succeed
    Given all existing pods die with labels:
      | app=pi |
    When I run the :get client command with:
      | resource | pods |
      | l | app=pi |
    Then the step should succeed
    And the output should not contain "pi-"
    Given I replace lines in "job.yaml":
      | completions: 5 | completions: -1 |
    When I run the :create client command with:
      | f | job.yaml |
    Then the step should fail
    And the output should contain "must be greater than or equal to 0"
    Given I replace lines in "job.yaml":
      | completions: -1 | completions: 0.1 |
    When I run the :create client command with:
      | f | job.yaml |
    Then the step should fail
    And the output should contain "fractional integer"
