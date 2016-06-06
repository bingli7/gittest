Feature: Persistent Volume Claim binding policies

  # @author jhou@redhat.com
  # @case_id 510615
  @admin @destructive
  Scenario: PVC with accessMode RWO could bound PV with accessMode RWO
    # Preparations
    Given I have a project

    # Create 2 PVs
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv-template-all-access-modes.json" where:
      | ["metadata"]["name"]      | nfs-<%= project.name %> |
    And admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv-template-rox-rwx.json" where:
      | ["metadata"]["name"]      | nfs1-<%= project.name %> |

    # Create 1 PVC
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/claim-rwo.json |

    # First PV can bound because it has RWO
    When I run the :get admin command with:
      | resource | pv/nfs-<%= project.name %> |
    Then the output should contain:
      | Bound |
      | nfsc  | # The PVC name it bounds to

    # Second PV can not bound because it does not have RWO
    When I run the :get admin command with:
      | resource | pv/nfs1-<%= project.name %> |
    Then the output should contain:
      | Available |

  # @author jhou@redhat.com
  # @case_id 510616
  @admin @destructive
  Scenario: PVC with accessMode RWX could bound PV with accessMode RWX
    # Preparations
    Given I have a project

    # Create 2 PVs
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv-template-all-access-modes.json" where:
      | ["metadata"]["name"]      | nfs-<%= project.name %> |
    And admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv-template-rwo-rox.json" where:
      | ["metadata"]["name"]      | nfs1-<%= project.name %> |

    # Create 1 PVC
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/claim-rwx.json |

    # First PV can bound because it has RWO
    When I run the :get admin command with:
      | resource | pv/nfs-<%= project.name %> |
    Then the output should contain:
      | Bound |
      | nfsc  | # The PVC name it bounds to

    # Second PV can not bound because it does not have RWO
    When I run the :get admin command with:
      | resource | pv/nfs1-<%= project.name %> |
    Then the output should contain:
      | Available |


  # @author yinzhou@redhat.com
  # @case_id 510610
  @admin @destructive
  Scenario: deployment hook volume inheritance -- with persistentvolumeclaim Volume
    Given I have a project
    And I have a NFS service in the project
    # Creating PV and PVC
    Given admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto-nfs-recycle-rwo.json" where:
      | ["spec"]["nfs"]["server"] | <%= service("nfs-service").ip %> |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/claim-rwo.json |
    Then the step should succeed
    And the PV becomes :bound

    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cases/510610/hooks-with-nfsvolume.json |
    Then the step should succeed
  ## mount should be correct to the pod, no-matter if the pod is completed or not, check the case checkpoint
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource  | pod  |
      | resource_name | hooks-1-hook-pre |
      |  o        | yaml |
    Then the output by order should match:
      | - mountPath: /opt1     |
      | name: v1               |
      | persistentVolumeClaim: |
      | claimName: nfsc        |
    """

  # @author wehe@redhat.com
  # @case_id 522131
  @admin @destructive
  Scenario: PVCs with size more than PV or access mode not supported by existing PV and expect pending
    Given I have a project
    And I have a NFS service in the project

    #Create PV by using create admin method to avoid the second time delete at pv.rb
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv-template.json"
    And I replace lines in "pv-template.json":
      |#NFS-Service-IP#|<%= service.ip %>|
    When admin creates a PV from "pv-template.json" where:
      | ["metadata"]["name"] | nfs-<%= project.name %> |
    Then the step should succeed

    #Create a bigger size pvc
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/claim-rwx.json"
    And I replace lines in "claim-rwx.json":
      |nfsc|nfsc-<%= project.name %>|
      |5Gi|10Gi|
    And I run the :create client command with:
      | f | claim-rwx.json |
    Then the step should succeed

    #Tricky method here, to avoid conflicting with other pv/pvc
    When I run the :get admin command with:
      | resource | pv |
      | resource_name | <%= pv.name %> |
    Then the output should not contain:
      | nfsc-<%= project.name %> |
    Given I run the :delete client command with:
      | object_type       | pvc  |
      | object_name_or_id | nfsc-<%= project.name %> |
    Then the step should succeed

    #Create unmathed pvc of rox
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/claim-rox.json"
    And I replace lines in "claim-rox.json":
      |nfsc|nfsc-<%= project.name %>|
    And I run the :create client command with:
      | f | claim-rox.json |
    Then the step should succeed

    #Verify the pv does not bind the pvc I created
    When I run the :get admin command with:
      | resource | pv |
      | resource_name | <%= pv.name %> |
    Then the output should not contain:
      | nfsc-<%= project.name %> |
    Given I run the :delete client command with:
      | object_type       | pvc  |
      | object_name_or_id | nfsc-<%= project.name %> |
    Then the step should succeed

    #Create rwo pvc
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/claim-rwo.json"
    And I replace lines in "claim-rwo.json":
      |nfsc|nfsc-<%= project.name %>|
    And I run the :create client command with:
      | f | claim-rwo.json |
    Then the step should succeed

    #Verify unbound here
    When I run the :get admin command with:
      | resource | pv |
      | resource_name | <%= pv.name %> |
    Then the output should not contain:
      | nfsc-<%= project.name %> |
    Given I run the :delete client command with:
      | object_type       | pvc  |
      | object_name_or_id | nfsc-<%= project.name %> |
    Then the step should succeed

    #Delete the pv by myself
    Given I run the :delete admin command with:
      | object_type       | pv   |
      | object_name_or_id | <%= pv.name %> |
    Then the step should succeed

    #Replace the access mode to RWO and then create pv
    And I replace lines in "pv-template.json":
      |ReadWriteMany|ReadWriteOnce|
    When admin creates a PV from "pv-template.json" where:
      | ["metadata"]["name"] | nfs-<%= project.name %> |
    Then the step should succeed

    #Create rwx pvc
    And I run the :create client command with:
      | f | claim-rwx.json |
    Then the step should succeed
    When I run the :get admin command with:
      | resource | pv |
      | resource_name | <%= pv.name %> |
    Then the output should not contain:
      | nfsc-<%= project.name %> |
    Given I run the :delete client command with:
      | object_type       | pvc  |
      | object_name_or_id | nfsc-<%= project.name %> |
    Then the step should succeed

    #Create rox pvc
    And I run the :create client command with:
      | f | claim-rox.json |
    Then the step should succeed
    When I run the :get admin command with:
      | resource | pv |
      | resource_name | <%= pv.name %> |
    Then the output should not contain:
      | nfsc-<%= project.name %> |
    Given I run the :delete client command with:
      | object_type       | pvc  |
      | object_name_or_id | nfsc-<%= project.name %> |
    Then the step should succeed

    #Delete pv and recreate the pv with ROX with the method in pv.rb to delete the pv at the clean up step
    Given I run the :delete admin command with:
      | object_type       | pv   |
      | object_name_or_id | <%= pv.name %> |
    Then the step should succeed
    And I replace lines in "pv-template.json":
      |ReadWriteOnce|ReadOnlyMany|
    When admin creates a PV from "pv-template.json" where:
      | ["metadata"]["name"] | nfs-<%= project.name %> |
    Then the step should succeed

    #Create rwx pvc
    And I run the :create client command with:
      | f | claim-rwx.json |
    Then the step should succeed
    When I run the :get admin command with:
      | resource | pv |
      | resource_name | nfs-<%= project.name %> |
    Then the output should not contain:
      | nfsc-<%= project.name %> |
    Given I run the :delete client command with:
      | object_type       | pvc  |
      | object_name_or_id | nfsc-<%= project.name %> |
    Then the step should succeed

    #Create rwo pvc
    And I run the :create client command with:
      | f | claim-rwo.json |
    Then the step should succeed
    When I run the :get admin command with:
      | resource | pv |
      | resource_name | nfs-<%= project.name %> |
    Then the output should not contain:
      | nfsc-<%= project.name %> |


  # @author wehe@redhat.com
  # @case_id 501013
  @admin @destructive
  Scenario: PVCs with accessmode ROX could bound to PV accessmode contanis ROX
    Given I have a project
    And I have a NFS service in the project

    #Create RWXRWOROX pv
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv-template-RWXRWOROX.json"
    And I replace lines in "pv-template-RWXRWOROX.json":
      |#NFS-Service-IP#|<%= service.ip %>|
    When admin creates a PV from "pv-template-RWXRWOROX.json" where:
      | ["metadata"]["name"] | nfs-<%= project.name %> |
    Then the step should succeed

    #Create RWXRWO pv
    And I replace lines in "pv-template-RWXRWOROX.json":
      |,"ReadOnlyMany"||
    When admin creates a PV from "pv-template-RWXRWOROX.json" where:
      | ["metadata"]["name"] | nfs1-<%= project.name %> |
    Then the step should succeed

    #Create rox pvc
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/claim-rox.json"
    And I replace lines in "claim-rox.json":
      |nfsc|pvc-<%= project.name %>|
    And I run the :create client command with:
      | f | claim-rox.json |
    Then the step should succeed

    #To verify the test point in 3 ways
    When I run the :get client command with:
      | resource | pvc |
    Then the output should contain:
      | Bound |
    When I run the :get admin command with:
      | resource | pv/nfs-<%= project.name %> |
    Then the output should contain:
      | Bound |
    When I run the :get admin command with:
      | resource | pv/nfs1-<%= project.name %> |
    Then the output should not contain:
      | pvc-<%= project.name %> |

    #Create the pod using the pvc
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/web-pod.json"
    And I replace lines in "web-pod.json":
      |nfsc|pvc-<%= project.name %>|
    And I run the :create client command with:
      | f | web-pod.json |
    Then the step should succeed
    Given the pod named "nfs" becomes ready

    #Verify the mount path access
    When I execute on the pod:
      | touch | /mnt/wehe1 |
    When I execute on the "nfs-server" pod:
      | ls | /mnt/data |
    Then the output should contain:
      | wehe1 |

  # @author chaoyang@redhat.com
  # @case_id 501012
  @admin @destructive
  Scenario: PV and PVC bound with accessmod rwx
    Given I have a project
    And I have a NFS service in the project

    And admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv.json" where:
      | ["metadata"]["name"]       | nfs-<%= project.name %>          |
      | ["spec"]["nfs"]["server"]  | <%= service("nfs-service").ip %> |
      | ["spec"]["accessModes"][0] | ReadWriteOnce                    |
      | ["spec"]["accessModes"][1] | ReadWriteMany                    |
      | ["spec"]["accessModes"][2] | ReadOnlyMany                     |

    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/claim-rwx.json |

    When I run the :get client command with:
      | resource | pvc/nfsc |
    Then the output should contain:
      |Bound|

  # @author chaoyang@redhat.com
  # @case_id 501014
  @admin @destructive
  Scenario: PV and PVC does not bound due to mismatched accessmode
    Given I have a project
    And I have a NFS service in the project

    And admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/auto/pv.json" where:
      | ["metadata"]["name"]       | nfs-<%= project.name %>  |
      | ["spec"]["nfs"]["server"]  | <%= service("nfs-service").ip %> |
      | ["spec"]["accessModes"][0] | ReadWriteMany                    |
      | ["spec"]["accessModes"][1] | ReadOnlyMany                     |

    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/claim-rwo.json |

    When I run the :get client command with:
      | resource | pvc/nfsc |
    Then the output should contain:
      | Pending |

    And I run the :get admin command with:
      | resource | pv/nfs-<%= project.name %> |
    Then the output should contain:
      | Available |

  # @author chaoyang@redhat.com
  # @case_id 522215
  @admin @destructive
  Scenario: PV and PVC bound and unbound many times
    Given I have a project
    And I have a NFS service in the project

    #Create 20 pv
    Given I run the steps 20 times:
    """
    When admin creates a PV from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/tc522215/pv.json" where:
      | ["spec"]["nfs"]["server"]  | <%= service("nfs-service").ip %> |
    Then the step should succeed
    """
    
    Given 20 PVs become :available within 20 seconds with labels:
      |usedFor=tc522215|

    #Loop 5 times about pv and pvc bound and unbound
    Given I run the steps 5 times:
    """
    And I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/persistent-volumes/nfs/tc522215/pvc-20.json |
    Given 20 PVCs become :bound within 50 seconds with labels:
      |usedFor=tc522215| 
    Then I run the :delete client command with:
      | object_type  | pvc  |
      | all          | all  |
    Given 20 PVs become :available within 500 seconds with labels:
      |usedFor=tc522215|
    """
