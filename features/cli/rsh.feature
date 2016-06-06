Feature: rsh.feature

  # @author cryan@redhat.com
  # @case_id 497699
  Scenario: Check oc rsh for simpler access to a remote shell
    Given I have a project
    Then evaluation of `project.name` is stored in the :proj_name clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_two_containers.json |
    Then the step should succeed
    When I run the :rsh client command
    Then the step should fail
    And the output should contain "error: rsh requires a single Pod to connect to"
    When I run the :rsh client command with:
      | help ||
    Then the output should contain "Open a remote shell session to a container"
    Given the pod named "doublecontainers" becomes ready
    #NOTE: for the following rsh commands, the ordering of the table (and arguments)
    #is important. The pod should always be last, unless there is a command afterwards;
    #then the command (like ls) should be last. The timeout can be placed anywhere.
    When I run the :rsh client command with:
      | pod | doublecontainers |
      | _timeout | 10 |
      | _stdin | echo "my_test_string\n" |
    Then the step should succeed
    Then the output should contain "my_test_string"
    When I run the :rsh client command with:
      | c | hello-openshift-fedora |
      | pod | doublecontainers |
      | _timeout | 10 |
      | _stdin | echo "my_test_string\n" |
    Then the step should succeed
    Then the output should contain "my_test_string"
    When I run the :rsh client command with:
      | shell | /bin/bash |
      | pod | doublecontainers |
      | _timeout | 10 |
      | _stdin | echo "my_test_string\n" |
    Then the step should succeed
    When I run the :rsh client command with:
      | c | hello-openshift-fedora |
      | shell | /bin/bash |
      | pod | doublecontainers |
      | _timeout | 10 |
      | _stdin | echo "my_test_string\n" |
    Then the step should succeed
    Then the output should contain "my_test_string"
    When I run the :rsh client command with:
      | pod | doublecontainers |
      | command | ls |
      | _timeout | 10 |
    Then the step should succeed
    And the output should contain "bin"
    When I create a new project
    Then the step should succeed
    Then evaluation of `project.name` is stored in the :proj_name2 clipboard
    Given I use the "<%= cb.proj_name2 %>" project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_two_containers.json |
    Then the step should succeed
    Given the pod named "doublecontainers" becomes ready
    Given I use the "<%= cb.proj_name %>" project
    When I run the :rsh client command with:
      | n | <%= cb.proj_name2 %> |
      | pod | doublecontainers |
      | _timeout | 10 |
      | _stdin | echo "my_test_string\n" |
    Then the step should succeed
    Then the output should contain "my_test_string"

  # @author pruan@redhat.com
  # @case_id 497700
  Scenario: Check oc rsh with invalid options
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_two_containers.json |
    Then the step should succeed
    When I run the :rsh client command with:
      | options | -l |
    Then the step should fail
    And the output should contain "Error: unknown shorthand flag: 'l'"
    When I run the :rsh client command with:
      | app_name | double_containers |
      | options | -b |
    Then the step should fail
    And the output should contain "Error: unknown shorthand flag: 'b'"
    When I run the :rsh client command with:
      | app_name | double_containers |
      | options | --label=hello-openshift |
    Then the step should fail
    And the output should contain "Error: unknown flag: --label"
