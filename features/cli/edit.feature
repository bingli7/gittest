Feature: edit.feature

  # @author cryan@redhat.com
  # @case_id 497628
  Scenario: Edit inexistent resource via oc edit
    When I run the :edit client command with:
      | filename | test |
    Then the output should contain "the path "test" does not exist"

  # @author xxing@redhat.com
  # @case_id 497623
  Scenario: Edit the resource with the file
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | dc |
      | resource_name | hooks |
      | o             | json |
    And I save the output to file>hooks.json
    And I replace lines in "hooks.json":
      | Plqe5Wev | Plqchange |
    # Wait the deployment till complete
    Given I wait for the pod named "hooks-1-deploy" to die
    When I run the :replace client command with:
      | f | hooks.json |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | dc |
      | name     | hooks |
    Then the output should contain:
      | Deployment #2            |
      | MYSQL_PASSWORD=Plqchange |
