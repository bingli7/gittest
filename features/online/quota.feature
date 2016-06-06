Feature: ONLY ONLINE related feature's scripts in this file

  # @author bingli@redhat.com
  # @case_id 517567 517576 517577
  Scenario Outline: Request/limit would be overridden based on container's memory limit when master provides override ratio
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/online/<path>/<filename> |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | pod       |
      | name     | <podname> |
    Then the output should match:
      | <expr1> |
      | <expr2> |
      | <expr3> |
      | <expr4> |

    Examples:
      | path | filename | podname |expr1 | expr2 | expr3 | expr4 |
      | tc517567 | pod-limit-request.yaml    | pod-limit-request    | cpu:\\s*1170m | memory:\\s*600Mi | cpu:\\s*70m | memory:\\s*360Mi |
      | tc517576 | pod-limit-memory.yaml     | pod-limit-memory     | cpu:\\s*584m  | memory:\\s*300Mi | cpu:\\s*35m | memory:\\s*180Mi |
      | tc517577 | pod-no-limit-request.yaml | pod-no-limit-request | cpu:\\s*1     | memory:\\s*512Mi | cpu:\\s*60m | memory:\\s*307Mi |
