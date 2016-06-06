Feature: Some basic project related tests

  Scenario: project methods
    When I have a project
    Then I delete the project
    Given I create 10 new projects

  Scenario: steps loop test
    Given I run the steps 3 times:
    """
    When I create a new project
    """
