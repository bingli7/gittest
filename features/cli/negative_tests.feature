Feature: negative tests

  # @author pruan@redhat.com
  # @case_id 505047
  Scenario: Add automatic suggestions when "unknown command" errors happen in the CLI
    When I run the :exec_raw_oc_cmd_for_neg_tests client command with:
      | arg | labels |
    Then the step should fail
    And the output should contain:
      | unknown command "labels" for "oc" |
      | Did you mean this                 |
      | label                             |
    When I run the :exec_raw_oc_cmd_for_neg_tests client command with:
      | arg | creaet |
    Then the step should fail
    And the output should contain:
      | unknown command "creaet" for "oc" |
      | Did you mean this                 |
      | create                            |
    When I run the :exec_raw_oc_cmd_for_neg_tests client command with:
      | arg | teg |
    Then the step should fail
    And the output should contain:
      | unknown command "teg" for "oc" |
      | Did you mean this              |
      | tag                            |
