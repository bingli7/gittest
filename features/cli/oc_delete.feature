Feature: oc_delete.feature

  # @author cryan@redhat.com
  # @case_id 509041
  Scenario: Gracefully delete a pod with '--grace-period' option
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/graceful-delete/10.json |
    Given the pod named "grace10" becomes ready
    When I run the :get client command with:
      | resource | pods |
      | resource_name | grace10 |
      | o | yaml |
    Then the output should contain "terminationGracePeriodSeconds"
    When I run the :delete client command with:
      | object_type | pod |
      | l | name=graceful |
      | grace-period | 20 |
    Then the step should succeed
    Given 15 seconds have passed
    When I get project pods
    Then the step should succeed
    And the output should contain "Terminating"
    #The full 20 seconds have passed after this step
    Given 5 seconds have passed
    When I get project pods
    Then the step should succeed
    And the output should not contain "Terminating"
    And the output should not contain "Running"
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/graceful-delete/10.json |
    Given the pod named "grace10" becomes ready
    When I run the :get client command with:
      | resource | pods |
      | resource_name | grace10 |
      | o | yaml |
    Then the output should contain "terminationGracePeriodSeconds"
    When I run the :delete client command with:
      | object_type | pod |
      | l | name=graceful |
      | grace-period | 0 |
    Then the step should succeed
    When I get project pods
    Then the step should succeed
    And the output should not contain "Terminating"
    And the output should not contain "Running"

  # @author cryan@redhat.com
  # @case_id 509045
  # @bug_id 1277101
  @admin
  Scenario: The namespace will not be deleted until all pods gracefully terminate
    Given I have a project
    And evaluation of `project.name` is stored in the :prj1 clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/graceful-delete/40.json |
    Given all pods in the project are ready
    Given the project is deleted
    Given 10 seconds have passed
    When I run the :get admin command with:
      | resource | namespaces |
    #The namespace should not be immediately deleted,
    #because all pods in it have a graceful termination period.
    #If the namespace does not exist, it is due to bug 1277101
    #as noted in the @bug_id above.
    Then the output should match "<%= cb.prj1 %>\s+Terminating"
    When I run the :get admin command with:
      | resource | pods |
      | all_namespace | true |
    And the output should match "<%= pod.name %>.*Terminating"
    Given 30 seconds have passed
    When I run the :get admin command with:
      | resource | pods |
      | all_namespace | true |
    Then the step should succeed
    And the output should not match "<%= pod.name %>.*Terminating"

  # @author cryan@redhat.com
  # @case_id 509040
  Scenario: Default termination grace period is 30s if it's not set
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/graceful-delete/default.json |
    Given the pod named "grace-default" becomes ready
    When I run the :get client command with:
      | resource | pods |
      | resource_name | grace-default |
      | o | yaml |
    Then the output should contain "terminationGracePeriodSeconds: 30"
    When I run the :delete client command with:
      | object_type | pod |
      | l | name=graceful |
    Then the step should succeed
    Given 20 seconds have passed
    When I get project pods
    Then the step should succeed
    And the output should contain "Terminating"
    Given 11 seconds have passed
    When I get project pods
    Then the step should succeed
    And the output should not contain "Terminating"
    And the output should not contain "Running"

  # @author cryan@redhat.com
  # @case_id 509046
  Scenario: Verify pod is gracefully deleted when DeletionGracePeriodSeconds is specified.
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/graceful-delete/10.json |
    Given the pod named "grace10" becomes ready
    When I run the :get client command with:
      | resource | pods |
      | resource_name | grace10 |
      | o | yaml |
    Then the output should contain "terminationGracePeriodSeconds: 10"
    When I run the :delete client command with:
      | object_type | pod |
      | l | name=graceful |
    Then the step should succeed
    When I get project pods
    Then the step should succeed
    And the output should contain "Terminating"
    Given 10 seconds have passed
    When I get project pods
    Then the step should succeed
    And the output should not contain "Terminating"
    And the output should not contain "Running"

  # @author cryan@redhat.com
  # @case_id 509042
  Scenario: Pod should be immediately deleted if TerminationGracePeriodSeconds is 0
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/graceful-delete/0.json |
    Given the pod named "grace0" becomes ready
    When I run the :get client command with:
      | resource | pods |
      | resource_name | grace0 |
      | o | yaml |
    Then the output should contain "terminationGracePeriodSeconds: 0"
    When I run the :delete client command with:
      | object_type | pod |
      | l | name=graceful |
    Then the step should succeed
    When I get project pods
    Then the step should succeed
    And the output should not contain "Terminating"
    And the output should not contain "Running"

  # @author cryan@redhat.com
  # @case_id 474045
  Scenario: Delete resources with multiple approach via cli
    Given I have a project
    When I process and create "https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json"
    Given the "ruby-sample-build-1" build finished
    When I run the :delete client command with:
      | object_type | replicationcontroller |
      | object_name_or_id | database-1 |
    Then the step should succeed
    Given I get project replicationcontrollers
    Then the output should not contain "database-1"
    When I run the :delete client command with:
      | object_type | pods,services |
      | l | template=application-template-stibuild |
    Then the step should succeed
    Given I get project services
    Then the output should not contain:
      | database |
      | frontend |
    Given I download a file from "https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins-master/jenkins-master-template.json"
    Given I download a file from "https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins-master/jenkins-slave-template.json"
    When I run the :create client command with:
      | f | . |
    Then the step should succeed
    And the output should contain:
      | "jenkins-master" created |
      | "jenkins-slave-builder" created |
    When I run the :delete client command with:
      | f | . |
    Then the step should succeed
    And the output should contain:
      | "jenkins-master" deleted |
      | "jenkins-slave-builder" deleted |
    When I run the :create client command with:
      | f | . |
    Then the step should succeed
    And the output should contain:
      | "jenkins-master" created |
      | "jenkins-slave-builder" created |
    When I run the :delete client command with:
      | f | jenkins-master-template.json |
      | f | jenkins-slave-template.json |
    Then the step should succeed
    And the output should contain:
      | "jenkins-master" deleted |
      | "jenkins-slave-builder" deleted |
