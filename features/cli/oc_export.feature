Feature: oc exports related scenarios
  # @author pruan@redhat.com
  # @case_id 488095
  Scenario: Export resource as json format by oc export
    Given I have a project
    And I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/sample-php-centos7.json|
    Then the step should succeed
    And I create a new application with:
      | template | php-helloworld-sample |
    Then the step should succeed
    And I run the :get client command with:
      | resource | service |
    Then the step should succeed
    And the output should contain:
      | database |
      | frontend |
    And I run the :get client command with:
      | resource | dc |
    Then the step should succeed
    And the output should match:
      | database.*[Cc]onfig           |
      | frontend.*[Cc]onfig.*[Ii]mage |
    And I run the :export client command with:
      | resource | svc |
      | name     | frontend |
      | output_format | json |
    And evaluation of `JSON.parse(@result[:response])` is stored in the :export_svc clipboard
    Then the expression should be true> cb.export_svc['metadata']['labels']['template'] == "application-template-stibuild"
    Given I save the response to file> svc_output.json
    And I run the :export client command with:
      | resource | dc |
      | name     | frontend |
      | output_format | json |
    And evaluation of `JSON.parse(@result[:response])` is stored in the :export_dc clipboard
    Then the expression should be true> cb.export_dc['spec']['triggers'].to_s.include? 'ConfigChange'
    Then the expression should be true> cb.export_dc['spec']['triggers'].to_s.include? 'ImageChange'
    Given I save the response to file> dc_output.json
    Given I create a new project
    And I run the :create client command with:
      | f | svc_output.json |
    Then the step should succeed
    And I run the :create client command with:
      | f | dc_output.json |
    Then the step should succeed
    And I run the :get client command with:
      | resource | svc |
    Then the step should succeed
    And the output should contain:
      | frontend |
    And I run the :get client command with:
      | resource | dc |
    Then the step should succeed
    And the output should match:
      | frontend.*[Cc]onfig.*[Ii]mage |

  # @author pruan@redhat.com
  # @case_id 488096
  Scenario: Export resource as template format by oc export
    Given I have a project
    And I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/sample-php-centos7.json|
    Then the step should succeed
    And I create a new application with:
      | template | php-helloworld-sample |
    Then the step should succeed
    And I run the :get client command with:
      | resource | service |
    Then the step should succeed
    And the output should contain:
      | database |
      | frontend |
    And I run the :get client command with:
      | resource | dc |
    Then the step should succeed
    And the output should match:
      | database.*[Cc]onfig           |
      | frontend.*[Cc]onfig.*[Ii]mage |
    And I run the :export client command with:
      | resource | svc |
      | name     | frontend |
    Then the step should succeed
    And the output should contain:
      | template: application-template-stibuild |
    And I run the :export client command with:
      | resource | svc |
      | l | template=application-template-stibuild |
    Then the step should succeed
    And the output should contain:
      | template: application-template-stibuild |
    And evaluation of `@result[:response]` is stored in the :export_via_filter clipboard
    And I run the :export client command with:
      | resource | svc |
    And evaluation of `@result[:response]` is stored in the :export_all clipboard
    Given I save the response to file> export_all.yaml
    Then the expression should be true> cb.export_via_filter == cb.export_all
    And I create a new project
    And I run the :create client command with:
      | f | export_all.yaml |
    Then the step should succeed
    And I run the :get client command with:
      | resource | service |
    Then the step should succeed
    And the output should contain:
      | database |
      | frontend |

  # @author pruan@redhat.com
  # @case_id 488871
  Scenario: Negative test for oc export
    Given I have a project
    And I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/sample-php-centos7.json|
    Then the step should succeed
    And I create a new application with:
      | template | php-helloworld-sample |
    Then the step should succeed
    And I run the :get client command with:
      | resource | service |
    Then the step should succeed
    And the output should contain:
      | database |
      | frontend |
    And I run the :export client command with:
      | resource | svc |
      | name     | nonexist |
    Then the step should fail
    And the output should contain:
      | Error from server: services "nonexist" not found |
    And I run the :export client command with:
      | resource | dc |
      | name     | nonexist |
    Then the step should fail
    And the output should match:
      | eployment.*"nonexist" not found |
    And I run the :export client command with:
      | resource | svc |
      | l | name=nonexist|
    Then the step should fail
    And the output should contain:
      | no resources found - nothing to export |
    And I run the :export client command with:
      | resource | dc |
      | name     | frontend |
      | output_format | xyz |
    Then the step should fail
    And the output should contain:
      | error: output format "xyz" not recognized |

    # For sake of Online test in which one user can only create 1 project
    Given I switch to the second user
    And I have a project
    And I run the :get client command with:
      | resource | svc |
    Then the step should succeed
    And the output should not contain:
      | template |
    And I run the :export client command with:
      | resource | svc |
      | all | true |
    Then the output should contain:
      | error: no resources found - nothing to export |

  # @author pruan@redhat.com
  # @case_id 489300
  # TODO: currently this test will fail due to bug  https://bugzilla.redhat.com/show_bug.cgi?id=1276564
  Scenario: Convert a file to specific version by oc export
    Given I have a project
    When I run the :export client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1v1beta3.json |
      | output_version | v1 |
      | output_format  | json |
    And evaluation of `@result[:response]` is stored in the :export_489300_a clipboard
    Given I save the response to file> export_489300_a.json
    And I run the :create client command with:
      | f | export_489300_a.json |
    Then the step should succeed
    When I run the :export client command with:
      | f | export_489300_a.json |
      | output_version | v1beta3 |
      | output_format | json |
    And evaluation of `@result[:response]` is stored in the :export_489300_b clipboard
    Given I save the response to file> export_489300_b.json
    Then the step should succeed
    And I create a new project
    Then I run the :export client command with:
      | f | export_489300_b.json |
      | output_version | abc |
      | output_format | json |
    And evaluation of `@result[:response]` is stored in the :export_489300_c clipboard
    Given I save the response to file> export_489300_c.json
    And the expression should be true> cb.export_489300_c == cb.export_489300_b
