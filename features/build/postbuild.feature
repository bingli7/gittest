Feature: postbuild.feature
  # @author wewang@redhat.com
  # @case_id 519485
  Scenario: Implement post-build command for golang-ex
    Given I have a project
    And I run the :new_app client command with:
      | file     | https://raw.githubusercontent.com/openshift/golang-ex/master/openshift/templates/beego.json   |
    Then the step should succeed
    And the "beego-example-1" build was created
    And the "beego-example-1" build completed
    When I run the :build_logs client command with:
      | build_name | beego-example-1 |
    Then the output should contain:
      |RUN   TestArchive|
      |PASS: TestArchive|

