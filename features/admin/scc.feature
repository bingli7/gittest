Feature: SCC policy related scenarios
  # @author xiacwan@redhat.com
  # @case_id 511817
  @admin
  Scenario: Cluster-admin can add & remove user or group to from scc
    Given a 5 characters random string of type :dns is stored into the :scc_name clipboard
    When I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/scc_privileged.yaml"
    And I replace lines in "scc_privileged.yaml":
      | scc-pri | <%= cb.scc_name %> |
    And I switch to cluster admin pseudo user
    Given the following scc policy is created: scc_privileged.yaml
    Then the step should succeed

    When I run the :oadm_policy_add_scc_to_user admin command with:
      | scc   | <%= cb.scc_name %>  |
      | user_name  | <%= user(0, switch: false).name %>  |
    And I run the :oadm_policy_add_scc_to_user admin command with:
      | scc   | <%= cb.scc_name %>  |
      | user_name  | <%= user(1, switch: false).name %>  |
    And I run the :oadm_policy_add_scc_to_user admin command with:
      | scc       | <%= cb.scc_name %>  |
      | user_name |             |
      | serviceaccount | system:serviceaccount:default:default |
    And I run the :oadm_policy_add_scc_to_user admin command with:
      | scc       | <%= cb.scc_name %>  |
      | user_name | system:admin |
    And I run the :oadm_policy_add_scc_to_group admin command with:
      | scc       | <%= cb.scc_name %>  |
      | group_name | system:authenticated |
    When I run the :get admin command with:
      | resource | scc |
      | resource_name | <%= cb.scc_name %>  |
      | o        | yaml |
    Then the output should contain:
      |  <%= user(0, switch: false).name %>     |
      |  <%= user(1, switch: false).name %>     |
      |  system:serviceaccount:default:default  |
      |  system:admin  |
      |  system:authenticated |

    When I run the :oadm_policy_remove_scc_from_user admin command with:
      | scc        | <%= cb.scc_name %>  |
      | user_name  | <%= user(0, switch: false).name %>  |
    And I run the :oadm_policy_remove_scc_from_user admin command with:
      | scc        | <%= cb.scc_name %>  |
      | user_name  | <%= user(1, switch: false).name %>  |
    And I run the :oadm_policy_remove_scc_from_user admin command with:
      | scc        | <%= cb.scc_name %>  |
      | user_name  |             |
      | serviceaccount | system:serviceaccount:default:default |
    And I run the :oadm_policy_remove_scc_from_user admin command with:
      | scc        | <%= cb.scc_name %>  |
      | user_name  | system:admin |
    And I run the :oadm_policy_remove_scc_from_group admin command with:
      | scc        | <%= cb.scc_name %>  |
      | group_name | system:authenticated |
    When I run the :get admin command with:
      | resource | scc |
      | resource_name | <%= cb.scc_name %>  |
      | o        | yaml |
    Then the output should not contain:
      |  <%= user(0, switch: false).name %>  |
      |  <%= user(1, switch: false).name %>  |
      |  system:serviceaccount:default:default  |
      |  system:admin  |
      |  system:authenticated  |

  # @author bmeng@redhat.com
  # @case_id 495027
  @admin
  Scenario: Add/drop capabilities for container when SC matches the SCC
    Given I have a project

    # Create pod without SCC allowed
    When I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_cap_kill.json|
    Then the step should fail
    And the output should contain "capability may not be added"

    # Create SCC to allow KILL
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/scc_capabilities.yaml"
    And I replace lines in "scc_capabilities.yaml":
      |system:serviceaccounts:default|system:serviceaccounts:<%= project.name %>|
      |scc-cap|<%= rand_str(6, :dns) %>|
    Given the following scc policy is created: scc_capabilities.yaml

    # Create pod which match the allowed capability or not
    When I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_cap_kill.json|
    Then the step should succeed
    When I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_cap_chown.json|
    Then the step should fail
    And the output should contain:
      |CHOWN|
      |capability may not be added|

  # @author bmeng@redhat.com
  # @case_id 495028
  @admin
  Scenario: Pod can be created when its SC matches the SELinuxContextStrategy policy in SCC
    Given I have a project

    # Create pod which requests Selinux SecurityContext which does not match SCC SELinuxContext policy MustRunAs
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/scc_selinux_mustrunas.yaml"
    And I replace lines in "scc_selinux_mustrunas.yaml":
      |system:serviceaccounts:default|system:serviceaccounts:<%= project.name %>|
      |scc-selinux-mustrunas|<%= rand_str(6, :dns) %>|
    And the following scc policy is created: scc_selinux_mustrunas.yaml

    When I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_selinux.json|
    Then the step should fail
    And the output should contain:
      |does not match required user|
      |does not match required role|
      |does not match required level|
    When I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_nothing.json|
    Then the step should succeed

    # Create pod which requests Selinux SecurityContext when the SCC SELinuxContext policy is RunAsAny
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/scc_runasany.yaml"
    And I replace lines in "scc_runasany.yaml":
      |system:serviceaccounts:default|system:serviceaccounts:<%= project.name %>|
      |scc-runasany|<%= rand_str(6, :dns) %>|
    And the following scc policy is created: scc_runasany.yaml
    When I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_selinux.json|
    Then the step should succeed

  # @author bmeng@redhat.com
  # @case_id 495033
  @admin
  Scenario: The container with requests privileged in SC can be created only when the SCC allowed
    # Create privileged pod with default SCC
    Given I have a project
    When I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_privileged.json|
    Then the step should fail
    And the output should contain "Privileged containers are not allowed"

    # Create new scc to allow the privileged pod for specify project
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/scc_privileged.yaml"
    And I replace lines in "scc_privileged.yaml":
      |system:serviceaccounts:default|system:serviceaccounts:<%= project.name %>|
      |scc-pri|<%= rand_str(6, :dns) %>|
    And the following scc policy is created: scc_privileged.yaml

    # Create privileged pod again with new SCC
    When I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_privileged.json|
    Then the step should succeed

  # @author bmeng@redhat.com
  # @case_id 495031
  @admin
  Scenario: Limit the created container to access the hostdir via SCC
    # Create pod which request hostdir mount permission with default SCC
    Given I have a project
    When I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_hostdir.json|
    Then the step should fail
    And the output should match:
      |unable to validate against any security context constraint|
      |ost.*[Vv]olumes are not allowed |

    # Create new scc to allow the hostdir for pod in specify project
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/scc_hostdir.yaml"
    And I replace lines in "scc_hostdir.yaml":
      |system:serviceaccounts:default|system:serviceaccounts:<%= project.name %>|
      |scc-hostdir|<%= rand_str(6, :dns) %>|
    And the following scc policy is created: scc_hostdir.yaml

    # Create hostdir pod again with new SCC
    When I run the :create client command with:
      |f|https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_hostdir.json|
    Then the step should succeed

  # @author wjiang@redhat.com
  # @case_id 518942
  Scenario: [platformmanagement_public_586] Check if the capabilities work in pods
    Given I have a project
    When I run the :run client command with:
      |name|busybox|
      |image|openshift/busybox-http-app:latest|
    Then the step should succeed
    Given a pod becomes ready with labels:
      |deploymentconfig=busybox|
    When I run the :get client command with:
      |resource | pod|
    Then the step should succeed
    When I execute on the pod:
      |sh|
      |-c|
      |mknod /tmp/sda b 8 0 && echo ok|
    Then the output should match "Operation not permitted"
    When I execute on the pod:
      |sh|
      |-c|
      |touch /tmp/random && chown :$RANDOM /tmp/random && echo ok|
    Then the output should match "Operation not permitted"
    When I execute on the pod:
      |sh|
      |-c|
      |touch /tmp/random && chown 0 /tmp/random && echo ok|
    Then the output should match "Operation not permitted"
    When I execute on the pod:
      |sh|
      |-c|
      |chroot /tmp && echo ok|
    Then the output should match "Operation not permitted"
    When I execute on the pod:
      |sh|
      |-c|
      |kill -9 1 && if [[ `ls /proc/\|grep ^1$` == "" ]]; then echo ok;else echo "not ok"; fi;|
    Then the output should match "not ok"
