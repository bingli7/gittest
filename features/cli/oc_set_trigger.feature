Feature: oc set triggers tests
  # @author pruan@redhat.com
  # @case_id 519819
  Scenario: `oc set triggers` with misc flags
    Given I have a project
    And I run the :run client command with:
      | name  | hello                                               |
      | image | <%= project_docker_repo %>openshift/hello-openshift |
      | -l    | title=tc519819                                      |
    Then the step should succeed
    And I run the :run client command with:
      | name  | world                                               |
      | image | <%= project_docker_repo %>openshift/hello-openshift |
      | -l    | title=deadbeef_519819                               |
    Then the step should succeed
    And I run the :set_triggers client command with:
      | resource | dc             |
      | l        | title=tc519819 |
    Then the step should succeed
    And the output should contain "hello"
    And the output should not contain "deadbeef_519819"
    And I run the :set_triggers client command with:
      | resource   | dc   |
      | all        | true |
      | remove_all | true |
    Then the step should succeed
    And I run the :get client command with:
      | resource      | dc      |
      | resource_name | hello   |
      | o             | yaml    |
    Then the step should succeed
    And I save the output to file> dc.yaml
    And I run the :set_triggers client command with:
      | f        | dc.yaml            |
      | o        | go-template        |
      | t        | {{.metadata.name}} |
    Then the step should succeed
    And the output should contain "hello"
    And I run the :set_triggers client command with:
      | resource | dc    |
      | resource | hello |
      | resource | world |
    Then the step should succeed
    And the output should contain:
      | hello |
      | world |

  # @author pruan@redhat.com
  # @case_id 519817
  Scenario: `oc set triggers` for bc
    Given I have a project
    And I run the :new_build client command with:
      | app_repo |  centos/ruby-22-centos7~https://github.com/openshift/ruby-hello-world |
    Then the step should succeed
    And I run the :get client command with:
      | resource      | bc               |
      | resource_name | ruby-hello-world |
      | o             | yaml             |
    Then the output should contain "ruby-22-centos7:latest"
    And I run the :set_triggers client command with:
      | resource | bc               |
      | resource | ruby-hello-world |
    Then the step should succeed
    # remove triggers
    When I run the :set_triggers client command with:
      | resource    | bc               |
      | resource    | ruby-hello-world |
      | remove      | true             |
      | from_config | true             |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | bc               |
      | resource_name | ruby-hello-world |
      | o             | yaml             |
    Then the step should succeed
    And the output should not contain:
      | type: ConfigChange |
		# remove all triggers
    When I run the :set_triggers client command with:
      | resource   | bc               |
      | resource   | ruby-hello-world |
      | remove_all | true             |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | bc               |
      | resource_name | ruby-hello-world |
      | o             | yaml             |
    And the output is parsed as YAML
    Then the expression should be true> @result[:parsed]['spec']['triggers'].count == 0
    # 4. add triggers one at a time for now the triggers array will be in the order of FIFO
    When I run the :set_triggers client command with:
      | resource    | bc               |
      | resource    | ruby-hello-world |
      | from_config | true             |
    Then the step should succeed
    When I run the :set_triggers client command with:
      | resource   | bc                     |
      | resource   | ruby-hello-world       |
      | from_image | ruby-22-centos7:latest |
    Then the step should succeed
    When I run the :set_triggers client command with:
      | resource    | bc               |
      | resource    | ruby-hello-world |
      | from_github | true             |
    Then the step should succeed
    When I run the :set_triggers client command with:
      | resource     | bc               |
      | resource     | ruby-hello-world |
      | from_webhook | true             |
    Then the step should succeed
    # add imagechange trigger using another im tag
    When I run the :set_triggers client command with:
      | resource   | bc                          |
      | resource   | ruby-hello-world            |
      | from_image | ruby-another-centos7:latest |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | bc               |
      | resource_name | ruby-hello-world |
      | o             | yaml             |
    And the output is parsed as YAML
    # just create a shorthand to save from typing long variables
    And evaluation of `@result[:parsed]['spec']['triggers']` is stored in the :triggers clipboard
    Then the expression should be true> cb.triggers[0]['type'] == 'ConfigChange'
    Then the expression should be true> cb.triggers[1]['type'] == 'ImageChange'
    Then the expression should be true> cb.triggers[2]['type'] == 'GitHub' && cb.triggers[2]['github'].has_key?('secret')
    Then the expression should be true> cb.triggers[3]['type'] == 'Generic' && cb.triggers[3]['generic'].has_key?('secret')
    Then the expression should be true> cb.triggers[4]['type'] == 'ImageChange' && cb.triggers[4]['imageChange']['from']['name'] == "ruby-another-centos7:latest"

  # @author pruan@redhat.com
  # @case_id 519818
  Scenario: `oc set triggers` for dc
    Given I have a project
    And I run the :create client command with:
    	| f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/dc-with-two-containers.yaml |
    Then the step should succeed
    When I run the :set_triggers client command with:
      | resource   | dc/dctest              |
      | from_image | hello-openshift:latest |
      | containers | dctest-1,dctest-2      |
      | manual     | true                   |
    Then the step should succeed
    When I run the :set_triggers client command with:
      | resource | dc/dctest |
    Then the step should succeed
    And the output should match:
      | deploymentconfigs/dctest\\s+image\\s+hello-openshift:latest\\s+\(dctest\-1, dctest\-2\)\\s+false |
    When I run the :set_triggers client command with:
      | resource   | dc/dctest            |
      | from_image | hello-openshift:tag1 |
      | containers | dctest-1             |
      | auto       | true                 |
    Then the step should succeed
    When I run the :set_triggers client command with:
      | resource | dc/dctest |
    Then the step should succeed
    And the output should match:
      | deploymentconfigs/dctest\\s+image\\s+hello-openshift:tag1\\s+\(dctest\-1\)\\s+true |
    # remove triggers
    When I run the :set_triggers client command with:
      | resource    | dc/dctest |
      | from_config | true      |
      | remove      | true      |
    Then the step should succeed
    When I run the :get client command with:
      | resource | dc/dctest |
      | o        | yaml      |
    And the output is parsed as YAML
    Then the expression should be true> !@result[:parsed]['spec']['triggers'].inspect.include? 'ConfigChange'
    #remove all triggers
    And I run the :set_triggers client command with:
      | resource   | dc/dctest |
      | remove_all | true      |
    Then the step should succeed
    And I run the :get client command with:
      | resource | dc/dctest |
      | o        | yaml      |
    Then the step should succeed
    And the output is parsed as YAML
    # empty triggers array mean all triggers are removed
    Then the expression should be true> @result[:parsed]['spec']['triggers'].count == 0
    # negative tests
    When I run the :set_triggers client command with:
      | resource   | dc/dctest              |
      | from_image | hello-openshift:latest |
      | containers | deadbeef     |
    Then the step should fail
    And the output should contain:
      | not all container names exist: deadbeef |
    When I run the :set_triggers client command with:
      | resource   | dc/dctest              |
      | from_image | hello-openshift:latest |
      | containers | dctest-1               |
      | auto       | true                   |
      | manual     | true                   |
    Then the step should fail
    And the output should contain:
      | error: you must specify at most one of --auto or --manual |
