Feature: Postgresql images test

  # @author wewang@redhat.com
  # @case_id 473391
  Scenario: Add env variables to postgresql-92-rhel7 image
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/db-templates/postgresql-92-rhel7-env-test.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      |name=database|
    When I execute on the pod:
      | env |
    Then the output should contain:
      | POSTGRESQL_SHARED_BUFFERS=64MB |
      | POSTGRESQL_MAX_CONNECTIONS=42  |
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | bash |
      | -c |
      |psql -c 'show shared_buffers;'|
    Then the step should succeed
    """
    Then the output should contain:
      | shared_buffers |
      | 64MB           |
    #And the output should contain "64MB"
    And I execute on the pod:
      | bash |
      | -c |
      |psql -c 'show max_connections;'|
    Then the step should succeed
    Then the outputs should contain:
      | max_connections |
      | 42              |

  # @author wewang@redhat.com
  # @case_id 508068
  Scenario: Add env variables to postgresql-94-rhel7 image
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/db-templates/postgresql-94-rhel7-env-test.json|
    Then the step should succeed
    And a pod becomes ready with labels:
      |name=database|
    When I execute on the pod:
      | env  |
    Then the output should contain:
      | POSTGRESQL_SHARED_BUFFERS=64MB |
      | POSTGRESQL_MAX_CONNECTIONS=42  |
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | bash |
      | -c |
      |psql -c 'show shared_buffers;'|
    Then the step should succeed
    """
    Then the output should contain:
      | shared_buffers |
      | 64MB           |

    And I execute on the pod:
      | bash |
      | -c |
      |psql -c 'show max_connections;'|
    Then the step should succeed
    Then the output should contain:
      | max_connections |
      | 42              |

  # @author haowang@redhat.com
  # @case_id 511970
  Scenario: postgresql-ephemeral with postgresql-92-rhel7 image
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/db-templates/postgresql-92-ephemeral-template.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      |name=postgresql|

  # @author cryan@redhat.com
  # @case_id 508069
  Scenario: Create nodejs postgresql applicaion - nodejs-010-rhel7
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/db-templates/nodejs-template-stibuild.json |
    Then the step should succeed
    Given the "nodejs-sample-build-1" build completes
    Given I get project routes
    Then the output should contain "route-edge"
    Given 2 pods become ready with labels:
      | deployment=frontend-1 |
    When I execute on the "<%= pod.name %>" pod:
      | curl | localhost:8080 |
    Then the output should contain:
      | Hello |
      | 0.10  |
      | 9.2   |
