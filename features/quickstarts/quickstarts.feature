Feature: quickstarts.feature

  # @author cryan@redhat.com haowang@redhat.com
  # @case_id 497613 512250 497612 512249 508748 512248 497668 497669 508737
  Scenario Outline: quickstart test
    Given I have a project
    When I run the :new_app client command with:
      | template | <template> |
    Then the step should succeed
    And the "<buildcfg>-1" build was created
    And the "<buildcfg>-1" build completed
    And <podno> pods become ready with labels:
      |app=<template>|
    When I use the "<buildcfg>" service
    Then I wait for a web server to become available via the "<buildcfg>" route
    Then the output should contain "<output>"

    Examples: OS Type
      | template                  | buildcfg                 | output  | podno |
      | django-example            | django-example           | Django  | 1     |
      | django-psql-example       | django-psql-example      | Django  | 2     |
      | dancer-example            | dancer-example           | Dancer  | 1     |
      | dancer-mysql-example      | dancer-mysql-example     | Dancer  | 2     |
      | cakephp-example           | cakephp-example          | CakePHP | 1     |
      | cakephp-mysql-example     | cakephp-mysql-example    | CakePHP | 2     |
      | nodejs-example            | nodejs-example           | Node.js | 1     |
      | nodejs-mongodb-example    | nodejs-mongodb-example   | Node.js | 2     |
      | rails-postgresql-example  | rails-postgresql-example | Rails   | 2     |

  # @author cryan@redhat.com
  # @case_id 499621 499622
  Scenario Outline: Application with base images with oc command
    Given I have a project
    When I run the :new_app client command with:
      | file | <json> |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | python-sample-build |
    Then the step should succeed
    And the "python-sample-build-1" build was created
    And the "python-sample-build-1" build completed
    When I run the :get client command with:
      | resource | builds |
    Then the step should succeed
    And the output should contain "python-sample-build-1"
    When I run the :get client command with:
      | resource | service |
    Then the step should succeed
    And the output should contain:
      | database |
      | frontend |
    Given I wait for the "frontend" service to become ready
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl | -s | <%= service.url %> |
    Then the step should succeed
    """
    Then the output should contain "OpenShift"
    Examples:
      | json |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/python-27-rhel7-stibuild.json |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc499622/python-27-centos7-stibuild.json |

  # @author wzheng@redhat.com
  # @case_id 508716
  Scenario: Cakephp-ex quickstart hot deploy test - php-55-rhel7
    Given I have a project
    And I download a file from "https://raw.githubusercontent.com/openshift/cakephp-ex/master/openshift/templates/cakephp.json"
    Given I replace lines in "cakephp.json":
      | 5.6 | 5.5 |
    When I run the :new_app client command with:
      | file | cakephp.json |
    Then the step should succeed
    When I use the "cakephp-example" service
    Then I wait for a web server to become available via the "cakephp-example" route
    Then the output should contain "Welcome to OpenShift"
    Given I wait for the "cakephp-example" service to become ready
    When I execute on the pod:
      | sed | -i | s/Welcome/hotdeploy_test/g | /opt/app-root/src/app/View/Layouts/default.ctp |
    Then the step should succeed
    When I use the "cakephp-example" service
    Then I wait for a web server to become available via the "cakephp-example" route
    Then the output should contain "hotdeploy_test"

  # @author wzheng@redhat.com
  # @case_id 517344
  Scenario: Build with golang-ex repo
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/golang-ex/master/openshift/templates/beego.json |
    Then the step should succeed
    And the "beego-example-1" build was created
    And the "beego-example-1" build completed
    Then I wait for the "beego-example" service to become ready
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -s | <%= service.url %> |
    Then the step should succeed
    """
    Then the output should contain "Welcome to chat - beego sample app: Web IM"

  # @author wzheng@redhat.com
  # @case_id 508795
  Scenario: Cakephp-ex quickstart with mysql - php-55-rhel7
    Given I have a project
    And I download a file from "https://raw.githubusercontent.com/openshift/cakephp-ex/master/openshift/templates/cakephp-mysql.json"
    Given I replace lines in "cakephp-mysql.json":
      | 5.6 | 5.5 |
    When I run the :new_app client command with:
      | file | cakephp-mysql.json |
    Then the step should succeed
    And the "cakephp-mysql-example-1" build was created
    And the "cakephp-mysql-example-1" build completed
    Then I wait for the "cakephp-mysql-example" service to become ready
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -s | <%= service.url %> |
    Then the step should succeed
    """
    Then the output should contain "Welcome to your CakePHP application on OpenShift"

  # @author dyan@redhat.com
  # @case_id 479059
  Scenario: Use the template parameters for the entire config
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc479059/application-template-parameters.json |
    Then the step should succeed
    And the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completed

