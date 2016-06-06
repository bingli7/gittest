Feature: oc_process.feature

  # @author haowang@redhat.com
  # @case_id 439003 439004
  Scenario Outline: Should give a error message while generator is nonexistent or the value is invalid
    Given I have a project
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/sample-php-rhel7.json"
    And I replace lines in "sample-php-rhel7.json":
      | <beforreplace> | <afterreplace> |
    Then I run the :process client command with:
      | f | sample-php-rhel7.json |
    And the step should succeed
    And the output should contain:
      | <output>  |
    Examples:
      | beforreplace | afterreplace | output                              |
      | expression   | test         | test |
      | A-Z          | A-Z0-z       | invalid range specified             |
  # @author haowang@redhat.com
  # @case_id 474030
  Scenario: "oc process" handles invalid json file
    Given I have a project
    Then I run the :process client command with:
      | f | non.json |
    And the step should fail
    And the output should contain:
      | does not exist |
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/sample-php-rhel7.json"
    And I replace lines in "sample-php-rhel7.json":
      | , |  |
    Then I run the :process client command with:
      | f | sample-php-rhel7.json |
    And the step should fail
    And the output should contain:
      | nvalid character |
