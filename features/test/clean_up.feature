Feature: some clean up steps testing
  Scenario: define clean-up in different ways
    Given I register clean-up steps:
      |I log the message> Message 1  |
      |I log the messages:           |
      |! Message 2!Message 3!        |
    And I register clean-up steps:
    """
    I log the messages:
      | Message 4 | Message 5 |
      | Message 6 | Message 7 |
    I log the message> Message 8
    I fail the scenario
    """
    Then I do nothing
