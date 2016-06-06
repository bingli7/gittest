Feature: Add, update remove volume to rc/dc and --overwrite option

  # @author jialiu@redhat.com
  # @author jhou@redhat.com
  # @case_id 491430
  @admin @destructive
  Scenario: Add/Remove persistentVolumeClaim to dc and rc and '--overwrite' option
    # Preparations
    Given I have a project
    And I have a NFS service in the project
    When I run the :new_app client command with:
      | image_stream | openshift/mongodb |
      | env | MONGODB_USER=tester,MONGODB_PASSWORD=xxx,MONGODB_DATABASE=testdb,MONGODB_ADMIN_PASSWORD=yyy |
      | name | mydb |
    Then the step should succeed
    And a pod becomes ready with labels:
      | app=mydb |
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv-template.json" where:
      | ["spec"]["nfs"]["server"] | <%= service("nfs-service").ip %> |
      | ["metadata"]["name"]      | nfs-<%= project.name %>          |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pvc-template.json" replacing paths:
      | ["metadata"]["name"]   | nfsc-<%= project.name %> |
      | ["spec"]["volumeName"] | nfs-<%= project.name %>  |
    Then the step should succeed
    And the PV becomes :bound
    And the "nfsc-<%= project.name %>" PVC becomes :bound
    # add pvc to dc
    When I run the :volume client command with:
      | resource      | dc/mydb                 |
      | action        | --add                   |
      | type          | persistentVolumeClaim   |
      | mount-path    | /opt1                   |
      | name          | v1                      |
      | claim-name    | nfsc-<%= project.name %>|
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    # check after add pvc to dc
    When I run the :get client command with:
      | resource      | dc/mydb            |
      | output        | yaml               |
    And the output should contain:
      | - mountPath: /opt1         |
      | - name: v1                 |
      |   persistentVolumeClaim:   |
      |   claimName: nfsc-<%= project.name %>|
    When I run the :get client command with:
      | resource      | rc/mydb-2          |
      | output        | yaml               |
    And the output should contain:
      | - mountPath: /opt1         |
      | - name: v1                 |
      |   persistentVolumeClaim:   |
      |   claimName: nfsc-<%= project.name %>|
    When I execute on the pod:
      | grep | opt1 | /proc/mounts |
    Then the step should succeed
    # remove pvc from dc
    When I run the :volume client command with:
      | resource      | dc/mydb               |
      | action        | --remove              |
      | name          | v1                    |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    # check after remove pvc from dc
    When I run the :get client command with:
      | resource      | dc/mydb            |
      | output        | yaml               |
    And the output should not contain:
      |   name: v1                 |
    When I run the :get client command with:
      | resource      | rc/mydb-3          |
      | output        | yaml               |
    And the output should not contain:
      |   name: v1                 |
    When I execute on the pod:
      | grep | opt1 | /proc/mounts |
    Then the step should fail
    # add pvc to rc
    When I run the :volume client command with:
      | resource      | rc/mydb-3               |
      | action        | --add                   |
      | type          | persistentVolumeClaim   |
      | mount-path    | /opt2                   |
      | name          | v2                      |
      | claim-name    | nfsc-<%= project.name %>|
    Then the step should succeed
    # check after add pvc to rc
    When I run the :get client command with:
      | resource      | rc/mydb-3            |
      | output        | yaml                 |
    And the output should contain:
      | - mountPath: /opt2         |
      | - name: v2                 |
      |   persistentVolumeClaim:   |
      |   claimName: nfsc-<%= project.name %>|
    When I run the :delete client command with:
      | object_type   | pod                   |
      | l             | app=mydb              |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    When I execute on the pod:
      | grep | opt2 | /proc/mounts |
    Then the step should succeed
    # remove pvc from rc
    When I run the :volume client command with:
      | resource      | rc/mydb-3               |
      | action        | --remove                |
      | name          | v2                      |
    Then the step should succeed
    # check after remove pvc from rc
    When I run the :get client command with:
      | resource      | rc/mydb-3            |
      | output        | yaml                 |
    And the output should not contain:
      |   name: v2                 |
    When I run the :delete client command with:
      | object_type   | pod                   |
      | l             | app=mydb              |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    When I execute on the pod:
      | grep | opt2 | /proc/mounts |
    Then the step should fail
    # add pvc to dc with '--overwrite' option
    When I run the :volume client command with:
      | resource      | dc/mydb                 |
      | action        | --add                   |
      | type          | persistentVolumeClaim   |
      | mount-path    | /var/lib/mongodb/data   |
      | claim-name    | nfsc-<%= project.name %>|
    Then the step should fail
    And the output should contain:
      |   already exists         |
    When I run the :volume client command with:
      | resource      | dc/mydb                 |
      | action        | --add                   |
      | type          | persistentVolumeClaim   |
      | mount-path    | /var/lib/mongodb/data   |
      | name          | mydb-volume-1           |
      | claim-name    | nfsc-<%= project.name %>|
    Then the step should fail
    And the output should contain:
      | Use --overwrite to replace |
    When I run the :volume client command with:
      | resource      | dc/mydb                 |
      | action        | --add                   |
      | type          | persistentVolumeClaim   |
      | mount-path    | /var/lib/mongodb/data   |
      | name          | mydb-volume-1           |
      | claim-name    | nfsc-<%= project.name %>|
      | overwrite     |                         |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    When I execute on the pod:
      | grep | mongodb | /proc/mounts |
    Then the step should succeed

  # @author jialiu@redhat.com
  # @case_id 491427
  Scenario: Add/Remove emptyDir volume to dc and rc
    # Preparations
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/mongodb |
      | env | MONGODB_USER=tester,MONGODB_PASSWORD=xxx,MONGODB_DATABASE=testdb,MONGODB_ADMIN_PASSWORD=yyy |
      | name | mydb |
    Then the step should succeed
    And a pod becomes ready with labels:
      | app=mydb |
    # add emptyDir to dc
    When I run the :volume client command with:
      | resource      | dc/mydb                 |
      | action        | --add                   |
      | type          | emptyDir                |
      | mount-path    | /opt1                   |
      | name          | v1                      |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    # check after add emptyDir to dc
    When I run the :get client command with:
      | resource      | dc/mydb            |
      | output        | yaml               |
    And the output should contain:
      | - mountPath: /opt1         |
      | - emptyDir: {}             |
      |   name: v1                 |
    When I run the :get client command with:
      | resource      | rc/mydb-2          |
      | output        | yaml               |
    And the output should contain:
      | - mountPath: /opt1         |
      | - emptyDir: {}             |
      |   name: v1                 |
    When I execute on the pod:
      | grep | opt1 | /proc/mounts |
    Then the step should succeed
    # remove emptyDir from dc
    When I run the :volume client command with:
      | resource      | dc/mydb               |
      | action        | --remove              |
      | name          | v1                    |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    # check after remove emptyDir from dc
    When I run the :get client command with:
      | resource      | dc/mydb            |
      | output        | yaml               |
    And the output should not contain:
      |   name: v1                 |
    When I run the :get client command with:
      | resource      | rc/mydb-3          |
      | output        | yaml               |
    And the output should not contain:
      |   name: v1                 |
    When I execute on the pod:
      | grep | opt1 | /proc/mounts |
    Then the step should fail
    # add emptyDir to rc
    When I run the :volume client command with:
      | resource      | rc/mydb-3               |
      | action        | --add                   |
      | type          | emptyDir                |
      | mount-path    | /opt2                   |
      | name          | v2                      |
    Then the step should succeed
    # check after add emptyDir to rc
    When I run the :get client command with:
      | resource      | rc/mydb-3            |
      | output        | yaml                 |
    And the output should contain:
      | - mountPath: /opt2         |
      | - emptyDir: {}             |
      |   name: v2                 |
    When I run the :delete client command with:
      | object_type   | pod                   |
      | l             | app=mydb              |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    When I execute on the pod:
      | grep | opt2 | /proc/mounts |
    Then the step should succeed
    # remove emptyDir from rc
    When I run the :volume client command with:
      | resource      | rc/mydb-3               |
      | action        | --remove                |
      | name          | v2                      |
    Then the step should succeed
    # check after remove emptyDir from rc
    When I run the :get client command with:
      | resource      | rc/mydb-3            |
      | output        | yaml                 |
    And the output should not contain:
      |   name: v2                 |
    When I run the :delete client command with:
      | object_type   | pod                   |
      | l             | app=mydb              |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    When I execute on the pod:
      | grep | opt2 | /proc/mounts |
    Then the step should fail

  # @author jialiu@redhat.com
  # @case_id 491429
  @admin @destructive
  Scenario: Add/Remove hostPath volume to dc and rc
    # Preparations
    Given I have a project
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/scc_super_template.yaml"
    And I replace lines in "scc_super_template.yaml":
      |#NAME#|<%= project.name %>|
      |#ACCOUNT#|<%= user.name %>|
      |#NS#|<%= project.name %>|
    Given the following scc policy is created: scc_super_template.yaml
    When I run the :new_app client command with:
      | image_stream | openshift/mongodb |
      | env | MONGODB_USER=tester,MONGODB_PASSWORD=xxx,MONGODB_DATABASE=testdb,MONGODB_ADMIN_PASSWORD=yyy |
      | name | mydb |
    Then the step should succeed
    And a pod becomes ready with labels:
      | app=mydb |
    # add hostPath to dc
    When I run the :volume client command with:
      | resource      | dc/mydb                 |
      | action        | --add                   |
      | type          | hostPath                |
      | mount-path    | /opt1                   |
      | path          | /usr                    |
      | name          | v1                      |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    # check after add hostPath to dc
    When I run the :get client command with:
      | resource      | dc/mydb            |
      | output        | yaml               |
    And the output should contain:
      | - mountPath: /opt1         |
      | - hostPath:                |
      |     path: /usr             |
      |   name: v1                 |
    When I run the :get client command with:
      | resource      | rc/mydb-2          |
      | output        | yaml               |
    And the output should contain:
      | - mountPath: /opt1         |
      | - hostPath:                |
      |     path: /usr             |
      |   name: v1                 |
    When I execute on the pod:
      | grep | opt1 | /proc/mounts |
    Then the step should succeed
    When I execute on the pod:
      | ls | /opt1/ |
    Then the output should contain:
      | sbin |
    # remove hostPath from dc
    When I run the :volume client command with:
      | resource      | dc/mydb               |
      | action        | --remove              |
      | name          | v1                    |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    # check after remove hostPath from dc
    When I run the :get client command with:
      | resource      | dc/mydb            |
      | output        | yaml               |
    And the output should not contain:
      |   name: v1                 |
    When I run the :get client command with:
      | resource      | rc/mydb-3          |
      | output        | yaml               |
    And the output should not contain:
      |   name: v1                 |
    When I execute on the pod:
      | grep | opt1 | /proc/mounts |
    Then the step should fail
    When I execute on the pod:
      | ls | /opt1/sbin |
    Then the step should fail
    # add hostPath to rc
    When I run the :volume client command with:
      | resource      | rc/mydb-3               |
      | action        | --add                   |
      | type          | hostPath                |
      | mount-path    | /opt2                   |
      | path          | /usr                    |
      | name          | v2                      |
    Then the step should succeed
    # check after add hostPath to rc
    When I run the :get client command with:
      | resource      | rc/mydb-3            |
      | output        | yaml                 |
    And the output should contain:
      | - mountPath: /opt2         |
      | - hostPath:                |
      |     path: /usr             |
      |   name: v2                 |
    When I run the :delete client command with:
      | object_type   | pod                   |
      | l             | app=mydb              |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    When I execute on the pod:
      | grep | opt2 | /proc/mounts |
    Then the step should succeed
    When I execute on the pod:
      | ls | /opt2/ |
    Then the output should contain:
      | sbin |
    # remove hostPath from rc
    When I run the :volume client command with:
      | resource      | rc/mydb-3               |
      | action        | --remove                |
      | name          | v2                      |
    Then the step should succeed
    # check after remove emptyDir from rc
    When I run the :get client command with:
      | resource      | rc/mydb-3            |
      | output        | yaml                 |
    And the output should not contain:
      |   name: v2                 |
    When I run the :delete client command with:
      | object_type   | pod                   |
      | l             | app=mydb              |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    When I execute on the pod:
      | grep | opt2 | /proc/mounts |
    Then the step should fail
    When I execute on the pod:
      | ls | /opt2/sbin |
    Then the step should fail

  # @author chaoyang@redhat.com
  # @case_id 499636
  @admin @destructive
  Scenario: Create a claim when adding volumes to dc/rc
    Given I have a project
    Given I have a NFS service in the project

    # Creating PV
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv.json" where:
      | ["spec"]["nfs"]["server"] | <%= service("nfs-service").ip %> |
    Then the step should succeed

    # new-app
    When I run the :new_app client command with:
      |image_stream | openshift/postgresql |
      |env          | POSTGRESQL_USER=tester |
      |env          | POSTGRESQL_PASSWORD=xxx|
      |env          | POSTGRESQL_DATABASE=testdb|
      |name         | mydb                 |
    Then the step should succeed
    And a pod becomes ready with labels:
      | app=mydb |

    When I run the :volume client command with:
      |resource| dc |
      |resource_name | mydb |
      |action|--add |
      |type|persistentVolumeClaim|
      |claim-mode | ReadWriteMany |
      |claim-name | nfsc-<%= project.name %> |
      |claim-size | 5 |
      |name       | mydb |
      |mount-path | /opt111 |
    Then the step should succeed

    When I run the :volume client command with:
      |resource | dc |
      |resource_name | mydb |
      |action | --list |
    Then the step should succeed
    Then the output should contain:
      |nfsc-<%= project.name %>|
      |mounted at /opt111      |

    #Verify the PVC mode, size, name are correctly created, the PVC has bound the PV
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    And the "nfsc-<%= project.name %>" PVC becomes :bound

    #Verify the pod has mounted the nfs
    When I execute on the pod:
      | grep | opt111 | /proc/mounts |
    Then the step should succeed

  # @author lxia@redhat.com
  # @case_id 519349
  @admin
  @destructive
  Scenario: Pod should be able to mount multiple PVCs
    # Preparations
    Given I have a project
    And I have a NFS service in the project
    When I execute on the pod:
      | bash |
      | -c   |
      | mkdir -p /mnt/mydata ; echo '/mnt/mydata *(rw,sync,no_root_squash,insecure)' >> /etc/exports ; exportfs -a |
    Then the step should succeed

    When I run the :new_app client command with:
      | image_stream | openshift/mongodb |
      | env | MONGODB_USER=tester,MONGODB_PASSWORD=xxx,MONGODB_DATABASE=testdb,MONGODB_ADMIN_PASSWORD=yyy |
      | name | mydb |
    Then the step should succeed
    And a pod becomes ready with labels:
      | app=mydb |

    # create 2 PVs and PVCs
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv-template.json" where:
      | ["spec"]["nfs"]["server"] | <%= service("nfs-service").ip %> |
      | ["metadata"]["name"]      | nfs-<%= project.name %>          |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pvc-template.json" replacing paths:
      | ["metadata"]["name"]   | nfsc-<%= project.name %> |
      | ["spec"]["volumeName"] | nfs-<%= project.name %>  |
    Then the step should succeed
    And the PV becomes :bound
    And the "nfsc-<%= project.name %>" PVC becomes :bound

    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv-template.json" where:
      | ["spec"]["nfs"]["server"] | <%= service("nfs-service").ip %> |
      | ["metadata"]["name"]      | nfs1-<%= project.name %>         |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pvc-template.json" replacing paths:
      | ["metadata"]["name"]   | nfsc1-<%= project.name %> |
      | ["spec"]["volumeName"] | nfs1-<%= project.name %>  |
    Then the step should succeed
    And the PV becomes :bound
    And the "nfsc1-<%= project.name %>" PVC becomes :bound

    # add pvc to dc
    When I run the :volume client command with:
      | resource   | dc/mydb               |
      | action     | --add                 |
      | type       | persistentVolumeClaim |
      | mount-path | /opt1                 |
      | name       | volume1               |
      | claim-name | nfsc-<%= project.name %> |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |
    When I run the :volume client command with:
      | resource   | dc/mydb               |
      | action     | --add                 |
      | type       | persistentVolumeClaim |
      | mount-path | /opt2                 |
      | name       | volume2               |
      | claim-name | nfsc1-<%= project.name %> |
    Then the step should succeed
    And I wait for the pod to die regardless of current status
    And a pod becomes ready with labels:
      | app=mydb |

    # check after add pvc to dc
    When I run the :get client command with:
      | resource | dc   |
      | output   | yaml |
    Then the step should succeed
    And the output should contain:
      | mountPath: /opt1       |
      | mountPath: /opt2       |
      | name: volume1          |
      | name: volume2          |
      | persistentVolumeClaim: |
      | claimName: nfsc-<%= project.name %>  |
      | claimName: nfsc1-<%= project.name %> |

    When I execute on the pod:
      | df |
    Then the step should succeed
    And the output should contain:
      | <%= service("nfs-service").ip %>:/ |
    When I execute on the pod:
      | mount |
    Then the step should succeed
    And the output should contain:
      | <%= service("nfs-service").ip %>:/ |
      | /opt1 |
      | /opt2 |

    When I run the :get client command with:
      | resource | pods |
      | output   | yaml |
    Then the step should succeed
    And the output should contain:
      | mountPath: /opt1       |
      | mountPath: /opt2       |
      | name: volume1          |
      | name: volume2          |
      | persistentVolumeClaim: |
      | claimName: nfsc-<%= project.name %>  |
      | claimName: nfsc1-<%= project.name %> |
