Feature: Persistent Volume Recycling

  # @author lxia@redhat.com
  # @case_id 507675
  @admin
  @destructive
  Scenario: PV recycling should work fine when there are dot files/dirs
    # Preparations
    Given I have a project
    And I have a NFS service in the project
    When I execute on the pod:
      | chmod | g+w | /mnt/data |
    Then the step should succeed

    # Creating PV and PVC
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv.json" where:
      | ["spec"]["nfs"]["server"] | <%= service("nfs-service").ip %> |
      | ["metadata"]["name"]      | nfs-<%= project.name %>          |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pvc-template.json" replacing paths:
      | ["metadata"]["name"]   | nfsc-<%= project.name %> |
      | ["spec"]["volumeName"] | nfs-<%= project.name %>  |
    Then the step should succeed
    And the PV becomes :bound
    And the "nfsc-<%= project.name %>" PVC becomes :bound

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/web-pod.json" replacing paths:
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | nfsc-<%= project.name %>  |
      | ["metadata"]["name"]                                         | mypod-<%= project.name %> |
    Then the step should succeed

    Given the pod named "mypod-<%= project.name %>" becomes ready

    When I execute on the pod:
      | df |
    Then the step should succeed
    When I execute on the pod:
      | touch | /mnt/.file1 | /mnt/.file2 | /mnt/file3 | /mnt/file4 |
    Then the step should succeed
    When I execute on the pod:
      | mkdir | -p | /mnt/.folder1 | /mnt/folder2 | /mnt/.folder3/.folder33 | /mnt/folder4/folder44 | /mnt/.folder5/folder55 | /mnt/folder6/.folder66 |
    Then the step should succeed

    When I run the :delete client command with:
      | object_type       | pod                       |
      | object_name_or_id | mypod-<%= project.name %> |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type       | pvc                      |
      | object_name_or_id | nfsc-<%= project.name %> |
    Then the step should succeed
    And the PV becomes :available within 300 seconds
    When I execute on the "nfs-server" pod:
      | ls | -a | /mnt/data/ |
    Then the output should not contain:
      | file |
      | folder |

