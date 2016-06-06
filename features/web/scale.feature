Feature: scale related features
  # @author yanpzhan@redhat.com
  # @case_id 510220
  Scenario: Could scale up and down on overview page
    When I create a new project via web
    Then the step should succeed

    #Create pod with dc
    Given I use the "<%= project.name %>" project
    When I run the :run client command with:
      | name         | mytest                    |
      | image        | aosqe/hello-openshift |
      | -l           | label=test |
    Then the step should succeed

    Given a pod becomes ready with labels:
      | label=test |

    When I perform the :goto_overview_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed

    #check replicas is 1
    When I perform the :check_pod_scaled_numbers web console action with:
      | scaled_number | 1 |
    Then the step should succeed

    #scale up 4 times
    Given I run the steps 4 times:
    """
    When I run the :scale_up_once web console action
    Then the step should succeed
    """
    #check replicas is 5
    And I wait until number of replicas match "5" for replicationController "mytest-1"
    And I perform the :check_pod_scaled_numbers web console action with:
      | scaled_number | 5 |
    Then the step should succeed

    #scale down 3 times
    Given I run the steps 3 times:
    """
    When I run the :scale_down_once web console action
    Then the step should succeed
    """
    #check replicas is 2
    And I wait until number of replicas match "2" for replicationController "mytest-1"
    Given I wait 180 seconds for the :check_pod_scaled_numbers web console action to succeed with:
      | scaled_number | 2 |

    #scale up 10 times
    Given I run the steps 10 times:
    """
    When I run the :scale_up_once web console action
    Then the step should succeed
    """
    And I wait until number of replicas match "12" for replicationController "mytest-1"
    #check replicas is 12
    And I perform the :check_pod_scaled_numbers web console action with:
      | scaled_number | 12 |
    Then the step should succeed

    #scale down 10 times
    Given I run the steps 10 times:
    """
    When I run the :scale_down_once web console action
    Then the step should succeed
    Given 3 seconds have passed
    """

    And I wait until number of replicas match "2" for replicationController "mytest-1"
    #check replicas is 2
    Given I wait 180 seconds for the :check_pod_scaled_numbers web console action to succeed with:
      | scaled_number | 2 |

    #scale down to 0
    When I run the :scale_down_once web console action
    Then the step should succeed

    When I run the :cancel_scale_down_to_zero web console action
    Then the step should succeed
    And I perform the :check_pod_scaled_numbers web console action with:
      | scaled_number | 1 |
    When I run the :scale_down_to_zero web console action
    Then the step should succeed

    Given I wait 180 seconds for the :check_pod_scaled_numbers web console action to succeed with:
      | scaled_number | 0 |

    #check the scale down button is disabled
    When I run the :check_scale_down_disabled web console action
    Then the step should succeed

    When I run the :scale_up_once web console action
    Then the step should succeed
