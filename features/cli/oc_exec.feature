Feature: containers related features
  # @author pruan@redhat.com
  # @case_id 472856
  Scenario: Choose container to execute command on with '-c' flag
    Given I have a project
    And evaluation of `"doublecontainers"` is stored in the :pod_name clipboard
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/double_containers.json  |
    Then the step should succeed
    And the pod named "doublecontainers" becomes ready
    When I run the :describe client command with:
      | resource | pod       |
      | name | <%= cb.pod_name %> |
    Then the output should contain:
      | Image:		jhou/hello-openshift |
      | Image:		jhou/hello-openshift-fedora |
    When I run the :exec client command with:
      | pod | <%= cb.pod_name %>  |
    #| c | hello-openshift |
      | exec_command | cat  |
      | exec_command_arg |/etc/redhat-release|
    Then the output should contain:
      | CentOS Linux release 7.0.1406 (Core) |
    When I run the :exec client command with:
      | pod | <%= cb.pod_name %>  |
      | c | hello-openshift-fedora |
      | exec_command | cat         |
      | exec_command_arg |/etc/redhat-release|
    Then the output should contain:
      | Fedora release 21 (Twenty One) |

  # @author xxing@redhat.com
  # @case_id 451911
  Scenario: Dumps logs from a given Pod container
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/hello-pod.json |
    Then the step should succeed
    Given the pod named "hello-openshift" becomes ready
    When I run the :get client command with:
      | resource | pods |
    Then the output should contain:
      | NAME           |
      | hello-openshift|
    When I run the :logs client command with:
      | resource_name | hello-openshift |
    Then the output should contain:
      | serving on 8081 |
      | serving on 8888 |

  # @author xxing@redhat.com
  # @case_id 497482
  Scenario: Add env variables to postgresql-92-centos7 image
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/db-templates/postgresql-92-centos7-env-test.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=database-1 |
    When I run the :get client command with:
      | resource | pods |
    Then the output should contain:
      | NAME            |
      | <%= pod.name %> |
    When I run the :describe client command with:
      | resource | pod             |
      | name     | <%= pod.name %> |
    Then the output should match:
      | Status:\\s+Running                        |
      | Image:\\s+openshift/postgresql-92-centos7 |
      | Ready\\s+True                             |
    When I execute on the pod:
      | bash                |
      | -c                  |
      | env \| grep POSTGRE |
    Then the output should contain:
      | POSTGRESQL_SHARED_BUFFERS=64MB |
      | POSTGRESQL_MAX_CONNECTIONS=42  |
    When I execute on the pod:
      | bash                           |
      | -c                             |
      | psql -c 'show shared_buffers;' |
    Then the output should contain:
      | shared_buffers |
      | 64MB           |
    And I execute on the pod:
      | bash                            |
      | -c                              |
      | psql -c 'show max_connections;' |
    Then the output should contain:
      | max_connections |
      | 42              |

  # @author pruan@redhat.com
  # @case_id 472859
  Scenario: Executing commands in a container that isn't running
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/tc472859/hello-pod.json|
    And the pod named "hello-openshift" status becomes :pending
    And I run the :exec client command with:
      | pod | hello-openshift |
      | container | hello-openshift |
      | exec_command | ls      |
    Then the step should fail
    And the output should contain:
      | error: pod hello-openshift is not running and cannot execute commands; current phase is Pending |

  # @author chaoyang@redhat.com
  # @case_id 472858
  Scenario: Executing command in inexistent containers
    When I have a project
    And I run the :create client command with:
      | filename |https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/hello-pod.json |
    Then the step should succeed
    And the pod named "hello-openshift" becomes ready
    When I execute on the "hello-openshift_notexist" pod:
      |date|
    Then the step should fail
    Then the output should contain:
      | Error from server: pods "hello-openshift_notexist" not found |
    When I run the :exec client command with:
      | pod   | hello-openshift  |
      | c | hello-openshift-notexist |
      | exec_command | date |
    Then the step should fail
    Then the output should contain:
      |Error from server: container hello-openshift-notexist is not valid for pod hello-openshift|

  # @author xiacwan@redhat.com
  # @case_id 472857
  Scenario: [origin_infra_311] Executing a command in container
    Given I have a project
    When I download a file from "https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json"
    And I replace lines in "hello-pod.json":
      | "openshift/hello-openshift" | <%= project_docker_repo %>"aosqe/hello-openshift"|
    Then the step should succeed
    When I run the :create client command with:
      | f       | hello-pod.json |
    Then the step should succeed
    Given the pod named "hello-openshift" becomes ready
    When I run the :exec client command with:
      | pod          | hello-openshift |
      | c                | hello-openshift |
      | i            |       |
      | t            |       |
      | oc_opts_end  |       |
      | exec_command | sh    |
      | exec_command_arg | -il    |
    Then the step should succeed
    When I execute on the pod:
      | sh                     |
      | -c                     |
      | env \| grep KUBERNETES |
    Then the output should contain:
      | KUBERNETES_PORT |
