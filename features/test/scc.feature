Feature: some SCC policy related scenarios

  @admin @destructive
  Scenario: NFS server
    Given I have a project
    And I have a NFS service in the project
    # one needs to verify scc is deleted upon scenario end

  @admin @destructive
  Scenario: restore SCC policy in tear_down
    Given scc policy "restricted" is restored after scenario
