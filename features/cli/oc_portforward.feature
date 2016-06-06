Feature: oc_portforward.feature

  # @author cryan@redhat.com
  # @case_id 472860
  Scenario: Forwarding a pod that isn't running
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/hello-pod-bad.json |
    Given the pod named "hello-openshift" status becomes :pending
    When I run the :port_forward client command with:
      | pod | hello-openshift |
      | port_spec | :8080 |
    Then the step should fail
    And the output should contain "Unable to execute command because pod is not running. Current status=Pending"

  # @author cryan@redhat.com
  # @case_id 472861
  Scenario: Forwarding local port to a pod
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/hello-pod.json |
    Then the step should succeed
    Given the pod named "hello-openshift" becomes ready
    When I run the :get client command with:
      | resource | pod |
    Then the output should contain "Running"
    When I run the :port_forward client command with:
      | pod | hello-openshift   |
      | port_spec | 5000:8080   |
      | _timeout | 10           |
    Then the step should have timed out
    And the output should match "Forwarding from 127.0.0.1:5000 -> 8080"
    When I run the :port_forward client command with:
      | pod | hello-openshift  |
      | port_spec | :8080      |
      | _timeout | 10          |
    Then the step should have timed out
    And the output should match "Forwarding from 127.0.0.1:\d+ -> 8080"
    When I run the :port_forward client command with:
      | pod | hello-openshift  |
      | port_spec | 8000:8080  |
      | _timeout | 10          |
    Then the step should have timed out
    And the output should match "Forwarding from 127.0.0.1:8000 -> 8080"

  # @author pruan@redhat.com
  # @case_id 509396
  Scenario: Forward multi local ports to a pod
    Given I have a project
    And evaluation of `rand(5000..7999)` is stored in the :porta clipboard
    And evaluation of `rand(5000..7999)` is stored in the :portb clipboard
    And evaluation of `rand(5000..7999)` is stored in the :portc clipboard
    And evaluation of `rand(5000..7999)` is stored in the :portd clipboard
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/double_containers.json |
    Given the pod named "doublecontainers" status becomes :running
    And I run the :port_forward background client command with:
      | pod | doublecontainers |
      | port_spec | <%= cb[:porta] %>:8080  |
      | port_spec | <%= cb[:portb] %>:8081  |
      | port_spec | <%= cb[:portc] %>:8080  |
      | port_spec | <%= cb[:portd] %>:8081  |
      | _timeout | 40 |
    Then the step should succeed
    And I wait up to 40 seconds for the steps to pass:
    """
    And I perform the HTTP request:
      <%= '"""' %>
      :url: 127.0.0.1:<%= cb[:porta] %>
      :method: :get
      <%= '"""' %>
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    And I perform the HTTP request:
      <%= '"""' %>
      :url: 127.0.0.1:<%= cb[:portb] %>
      :method: :get
      <%= '"""' %>
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    And I perform the HTTP request:
      <%= '"""' %>
      :url: 127.0.0.1:<%= cb[:portc] %>
      :method: :get
      <%= '"""' %>
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    And I perform the HTTP request:
      <%= '"""' %>
      :url: 127.0.0.1:<%= cb[:portd] %>
      :method: :get
      <%= '"""' %>
    """
  # @author pruan@redhat.com
  # @case_id 509397
  Scenario: Forwarding local port to a non-existing port in a pod
    Given I have a project
    And evaluation of `rand(5000..7999)` is stored in the :porta clipboard
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/double_containers.json |
    Given the pod named "doublecontainers" status becomes :running
    And I run the :port_forward background client command with:
      | pod       | doublecontainers        |
      | port_spec | <%= cb[:porta] %>:58087 |
      | _timeout  | 20                      |
    Then the step should succeed
    And I perform the HTTP request:
    """
      :url: 127.0.0.1:<%= cb[:porta] %>
      :method: :get
    """
    Then the step should fail
