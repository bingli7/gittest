Feature: ruby.feature

  # @author haowang@redhat.com
  # @case_id 521461 521462
  Scenario Outline: Tune puma workers according to memory limit ruby-22-rhel7 ruby-20-rhel7
    Given I have a project
    When I run the :create client command with:
      | f | <template> |
    Then the step should succeed
    Given the "rails-ex-1" build was created
    And the "rails-ex-1" build completed
    Given 1 pods become ready with labels:
      | app=rails-ex          |
      | deployment=rails-ex-1 |
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :logs client command with:
      | resource_name    | <%= pod.name %> |
    Then the output should contain:
      | Min threads: 0, max threads: 16 |
    """

    Examples:
      | template |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/tc521461/template.json |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/tc521462/template.json |

