Feature: Add pvc to pod from web related
  # @author yanpzhan@redhat.com
  # @case_id 515688
  @admin @destructive
  Scenario: Attach pvc to pod with multiple containers from web console
    When I create a new project via web
    Then the step should succeed
    And I have a NFS service in the project

    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv-template.json" where:
      | ["spec"]["nfs"]["server"]  | <%= service("nfs-service").ip %> |
      | ["metadata"]["name"]       | nfs-1-<%= project.name %>         |
    Then the step should succeed

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pvc-template.json" replacing paths:
      | ["metadata"]["name"]   | nfsc-1-<%= project.name %> |
      | ["spec"]["volumeName"] | nfs-1-<%= project.name %>  |
    Then the step should succeed
    Given the PV becomes :bound

    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv-template.json" where:
      | ["spec"]["nfs"]["server"]  | <%= service("nfs-service").ip %> |
      | ["metadata"]["name"]       | nfs-2-<%= project.name %>         |
    Then the step should succeed

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pvc-template.json" replacing paths:
      | ["metadata"]["name"]   | nfsc-2-<%= project.name %> |
      | ["spec"]["volumeName"] | nfs-2-<%= project.name %>  |
    Then the step should succeed
    Given the PV becomes :bound

    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/dc-with-two-containers.yaml |
    Then the step should succeed

    #Add pvc to one of the containers
    When I perform the :add_pvc_to_one_container web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | dctest              |
      | mount_path   | /mnt                |
      | volume_name  | v1                |
    Then the step should succeed
    And I wait until the status of deployment "dctest" becomes :complete

    Given 1 pods become ready with labels:
      | run=dctest |

    When I run the :exec client command with:
      | pod | <%= pod.name %>          |
      | c   | dctest-1                 |
      | exec_command | grep            |
      | exec_command_arg | mnt         |
      | exec_command_arg | /proc/mounts|
    Then the step should succeed

    #Add pvc to all containers by default
    When I perform the :add_pvc_to_all_default_containers web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | dctest              |
      | mount_path   | /tmp                |
      | volume_name  | v2                |
    Then the step should succeed
    And I wait until the status of deployment "dctest" becomes :complete

    Given 1 pods become ready with labels:
      | run=dctest |

    When I run the :exec client command with:
      | pod | <%= pod.name %>    |
      | c   | dctest-1           |
      | exec_command | touch     |
      | exec_command_arg |/tmp/f1|
    Then the step should succeed

    When I run the :exec client command with:
      | pod | <%= pod.name %>    |
      | c   | dctest-2           |
      | exec_command | ls        |
      | exec_command_arg |/tmp   |
    Then the step should succeed
    And the output should contain:
      | f1 |

  # @author yanpzhan@redhat.com
  # @case_id 515690
  @admin @destructive
  Scenario: Display and attach PVC to pod from web console
    Given I have a project
    And I have a NFS service in the project

    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv-template.json" where:
      | ["spec"]["nfs"]["server"]  | <%= service("nfs-service").ip %> |
      | ["metadata"]["name"]       | nfs-<%= project.name %>         |
    Then the step should succeed

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pvc-template.json" replacing paths:
      | ["metadata"]["name"]   | nfsc-<%= project.name %> |
      | ["spec"]["volumeName"] | nfs-<%= project.name %>  |
    Then the step should succeed

    Given the PV becomes :bound

    When I run the :run client command with:
      | name         | mytest                    |
      | image        |<%= project_docker_repo %>aosqe/hello-openshift |
      | -l           | label=test |
    Then the step should succeed
    Given 1 pods become ready with labels:
      | label=test |

    #Add pvc from rc page
    When I perform the :add_pvc_on_rc_page web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | mytest              |
      | dc_number    | 1                   |
      | mount_path   | /test               |
      | volume_name  | v1                  |
    Then the step should succeed
    When  I perform the :check_mount_info web console action with:
      | mount_path   | /test               |
      | volume_name  | v1                  |
    Then the step should succeed

    When I run the :delete client command with:
      | object_type   | pod                   |
      | l             | label=test            |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    Given 1 pods become ready with labels:
      | label=test |

    When I run the :exec client command with:
      | pod | <%= pod.name %>          |
      | exec_command | grep            |
      | exec_command_arg | test        |
      | exec_command_arg | /proc/mounts|
    Then the step should succeed

    When I run the :volume client command with:
      | resource      | rc/mytest-1             |
      | action        | --remove                |
      | name          | v1                      |
    Then the step should succeed

    #Add pvc from dc page
    When I perform the :add_pvc_to_all_default_containers web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | mytest              |
      | mount_path   | /mnt                |
      | volume_name  | v2                  |
    Then the step should succeed
    When  I perform the :check_mount_info web console action with:
      | mount_path   | /mnt               |
      | volume_name  | v2                 |
    Then the step should succeed

    And I wait until the status of deployment "mytest" becomes :complete

    Given 1 pods become ready with labels:
      | label=test |

    When I run the :exec client command with:
      | pod | <%= pod.name %>          |
      | exec_command | grep            |
      | exec_command_arg | mnt         |
      | exec_command_arg | /proc/mounts|
    Then the step should succeed

    When I run the :volume client command with:
      | resource      | dc/mytest               |
      | action        | --remove                |
      | name          | v2                      |
    Then the step should succeed

    #Add pvc from pod page
    When I perform the :add_pvc_to_pod web console action with:
      | project_name | <%= project.name %> |
      | pod_name     | <%= pod.name %>     |
      | mount_path   | /data               |
      | volume_name  | v3                  |
    Then the step should succeed

    And I wait until the status of deployment "mytest" becomes :complete

    Given 1 pods become ready with labels:
      | label=test |

    When I perform the :goto_one_pod_page web console action with:
      | project_name | <%= project.name %> |
      | pod_name     | <%= pod.name %>     |
    Then the step should succeed
    When  I perform the :check_mount_info web console action with:
      | mount_path   | /data              |
      | volume_name  | v3                 |
    Then the step should succeed

    When I run the :exec client command with:
      | pod | <%= pod.name %>           |
      | exec_command | grep             |
      | exec_command_arg | data         |
      | exec_command_arg | /proc/mounts |
    Then the step should succeed
