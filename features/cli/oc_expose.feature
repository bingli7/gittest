Feature: oc_expose.feature

  # @author cryan@redhat.com
  # @case_id 483243
  Scenario: Expose the second sevice from service
    Given I have a project
    When I run the :new_app client command with:
      | code | https://github.com/openshift/sti-perl |
      | l | app=test-perl|
      | context_dir | 5.20/test/sample-test-app/ |
      | name | myapp |
    Then the step should succeed
    And the "myapp-1" build completed
    When I run the :expose client command with:
      | resource | service |
      | resource_name | myapp |
      | port | 80 |
      | target_port | 8080 |
      | name | myservice |
      | generator  | service/v1 |
    Then the step should succeed
    When I run the :get client command with:
      | resource | service |
    Then the output should contain "myservice"
    And the output should contain "80/TCP"
    Given I wait for the "myservice" service to become ready
    And I wait up to 900 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -s | <%= service.url %> |
    Then the step should succeed
    """
    And the output should contain "Everything is OK"

  # @author akostadi@redhat.com
  # @case_id 483241
  Scenario: Expose services from deploymentconfig
    Given I have a project
    When I run the :new_app client command with:
      | app repo    | <%= product_docker_repo %>openshift3/perl-516-rhel7 |
      | code        | https://github.com/openshift/sti-perl    |
      | l           | app=test-perl                            |
      | context dir | 5.16/test/sample-test-app/               |
      | name        | myapp                                    |
      | insecure_registry | true                               |
    Then the step should succeed
    When I run the :expose client command with:
      | resource      | deploymentconfig |
      | resource name | myapp            |
      | target port   | 8080             |
      | generator     | service/v1       |
      | name          | myservice        |
    Given I wait for the "myservice" service to become ready
    When I execute on the pod:
      | curl | -k | <%= service.url %> |
    Then the step should succeed
    And the output should contain "Everything is fine."

  # @author xiuwang@redhat.com
  # @case_id 483240
  Scenario: Expose services from pod
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/perl:5.16                   |
      | code         | https://github.com/openshift/sti-perl |
      | l            | app=test-perl                         |
      | context dir  | 5.16/test/sample-test-app/            |
      | name         | myapp                                 |
    Then the step should succeed
    And a pod becomes ready with labels:
      | deploymentconfig=myapp  |
    When I run the :expose client command with:
      | resource      | pod                |
      | resource name | <%= pod.name %> |
      | target port   | 8080               |
      | generator     | service/v1         |
      | name          | myservice          |
    Given I wait for the "myservice" service to become ready
    When I execute on the pod:
      | curl | -k | <%= service.url %> |
    Then the step should succeed
    And the output should contain "Everything is fine."

  # @author yadu@redhat.com
  # @case_id 515695
  Scenario: Use service port name as route port.targetPort after 'oc expose service'
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cases/515695/svc_with_name.yaml |
    Then the step should succeed
    When I run the :expose client command with:
      | resource      | svc      |
      | resource name | frontend |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | route    |
      | resource_name | frontend |
      | template      | "{{.spec.port.targetPort}}" |
    Then the step should succeed
    And the output should contain "web"
    When I run the :delete client command with:
      | object_type       | service  |
      | object_name_or_id | frontend |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type       | route    |
      | object_name_or_id | frontend |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cases/515695/svc_without_name.yaml |
    Then the step should succeed
    When I run the :expose client command with:
      | resource      | svc      |
      | resource name | frontend |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | route    |
      | resource_name | frontend |
      | template      | "{{.spec.port.targetPort}}" |
    Then the step should succeed
    And the output should not contain "web"

  # @author xiuwang@redhat.com
  # @case_id 483242
  Scenario: Expose sevice from replicationcontrollers
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/perl                        |
      | code         | https://github.com/openshift/sti-perl |
      | context_dir  | 5.20/test/sample-test-app/            |
      | l            | app=test-perl                         |
      | name         | myapp                                 |
    Then the step should succeed
    And the "myapp-1" build completed
    Given I wait for the "myapp" service to become ready
    When I run the :expose client command with:
      | resource      | rc         |
      | resource_name | myapp-1    |
      | port          | 80         |
      | target_port   | 8080       |
      | name          | myservice  |
      | generator     | service/v1 |
    Then the step should succeed
    When I run the :get client command with:
      | resource | service |
    Then the output should contain:
      | myservice |
      | 80/TCP    |
    Given I wait for the "myservice" service to become ready
    And I wait up to 900 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -s | <%= service.url %> |
    Then the step should succeed
    """
    And the output should contain "Everything is OK"
