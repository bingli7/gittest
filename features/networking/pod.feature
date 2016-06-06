Feature: Service related networking scenarios
  # @author bmeng@redhat.com
  # @case_id 514976
  @admin
  Scenario: Pod cannot claim UDP port 4789 on the node as part of a port mapping
    Given I have a project
    And SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/pod_with_udp_port_4789.json |
    Then the step should succeed
    Given the pod named "hello-pod" status becomes :pending
    When I run the :describe client command with:
      | resource      | pod   |
    Then the output should contain "address already in use"
