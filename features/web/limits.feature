Feature: functions about resource limits on pod
  # @author yanpzhan@redhat.com
  # @case_id 517565
  Scenario: Pod template should contain cpu/memory limits when resources are set on pod

    Given I have a project
    When I run the :run client command with:
      | name         | mytest                    |
      | image        |<%= project_docker_repo %>aosqe/hello-openshift |
      | -l           | label=test |
      | limits       | cpu=300m,memory=300Mi|
      | requests     | cpu=150m,memory=250Mi|
    Then the step should succeed
    Given a pod becomes ready with labels:
      | label=test |

    When I perform the :check_limits_on_dc_page web console action with:
      | project_name | <%= project.name%> |
      | dc_name      | mytest             |
      | cpu_range    | 150 millicores to 300 millicores |
      | memory_range | 250 MiB to 300 MiB |
    Then the step should succeed

    When I perform the :check_limits_on_rc_page web console action with:
      | project_name | <%= project.name%> |
      | dc_name      | mytest             |
      | dc_number    | 1 |
      | cpu_range    | 150 millicores to 300 millicores |
      | memory_range | 250 MiB to 300 MiB |
    Then the step should succeed

    When I perform the :check_limits_on_pod_page web console action with:
      | project_name | <%= project.name%> |
      | pod_name     | <%= pod.name%>     |
      | cpu_range    | 150 millicores to 300 millicores |
      | memory_range | 250 MiB to 300 MiB |
    Then the step should succeed
