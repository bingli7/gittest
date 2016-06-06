Feature: hotdeploy.feature

  # @author wzheng@redhat.com
  # @case_id 508723,508727,508729,508731,508733,508725
  Scenario Outline: Hot deploy test
    Given I have a project
    When I create a new application with:
      | app_repo     | <app_repo>     |
      | image_stream | <image_stream> |
      | env          | <env>          |
    Then the step should succeed
    And the "<buildcfg>-1" build was created
    And the "<buildcfg>-1" build completed
    Given I wait for the "<buildcfg>" service to become ready
    When I execute on the pod:
      | sed | -i | <parameter> | <file_name> |
    Then the step should succeed
    When I expose the "<buildcfg>" service
    Then I wait for a web server to become available via the "<buildcfg>" route
    And the output should contain "hotdeploy_test"

    Examples:
      | app_repo | image_stream | env | buildcfg | parameter |  file_name |
      | https://github.com/openshift-qe/php-example-app.git  | openshift/php:5.5 | OPCACHE_REVALIDATE_FREQ=0 | php-example-app | s/Hello/hotdeploy_test/g | index.php |
      | https://github.com/openshift-qe/php-example-app.git  | openshift/php:5.6 | OPCACHE_REVALIDATE_FREQ=0 | php-example-app | s/Hello/hotdeploy_test/g | index.php |
      | https://github.com/openshift-qe/django-ex.git        | openshift/python:2.7 | APP_CONFIG=gunicorn.conf.py | django-ex  | s/Welcome/hotdeploy_test/g | /opt/app-root/src/welcome/templates/welcome/index.html |
      | https://github.com/openshift-qe/django-ex.git        | openshift/python:3.3 | APP_CONFIG=gunicorn.conf.py | django-ex  | s/Welcome/hotdeploy_test/g | /opt/app-root/src/welcome/templates/welcome/index.html |
      | https://github.com/openshift-qe/django-ex.git        | openshift/python:3.4 | APP_CONFIG=gunicorn.conf.py | django-ex  | s/Welcome/hotdeploy_test/g | /opt/app-root/src/welcome/templates/welcome/index.html |
      | https://github.com/openshift-qe/sinatra-hot-deploy.git | openshift/ruby:2.0 | RACK_ENV=development       | sinatra-hot-deploy | s/legen/hotdeploy_test/g | config.ru |

  # @author wzheng@redhat.com
  # @case_id 508735
  Scenario: Enable hot deploy for sinatra app - ruby-22-rhel7 which is created from imagestream via oc new-app
    Given I have a project
    When I create a new application with:
      | app_repo |https://github.com/openshift-qe/sinatra-hot-deploy-ruby22.git |
      | image_stream | openshift/ruby:2.2 |
      | env | RACK_ENV=development |
    Then the step should succeed
    And the "sinatra-hot-deploy-ruby22-1" build was created
    And the "sinatra-hot-deploy-ruby22-1" build completed
    Given I wait for the "sinatra-hot-deploy-ruby2" service to become ready
    When I execute on the pod:
      | sed | -i | s/Hello/hotdeploy_test/g | app.rb |
    Then the step should succeed
    When I expose the "sinatra-hot-deploy-ruby2" service
    Then I wait for a web server to become available via the "sinatra-hot-deploy-ruby2" route
    And the output should contain "hotdeploy_test"

  # @author wzheng@redhat.com
  # @case_id 508721,508719
  Scenario Outline: Enable hot deploy for perl which is created from imagestream via oc new-app
    Given I have a project
    When I create a new application with:
      | app_repo     | <app_repo>     |
      | image_stream | <image_stream> |
      | env          | <env>          |
      | context_dir  | <context_dir>      |
    Then the step should succeed
    And the "<buildcfg>-1" build was created
    And the "<buildcfg>-1" build completed
    Given I wait for the "<buildcfg>" service to become ready
    When I execute on the pod:
      | sed | -i | <parameter> | <file_name> |
    Then the step should succeed
    When I expose the "<buildcfg>" service
    Then I wait for a web server to become available via the "<buildcfg>" route
    And the output should contain "hotdeploy_test"

    Examples:
      | app_repo | image_stream | env | buildcfg | parameter |  file_name | context_dir |
      | https://github.com/openshift/sti-perl.git | openshift/perl:5.20 | PERL_APACHE2_RELOAD=true | sti-perl | s/fine/hotdeploy_test/g |index.pl | 5.20/test/sample-test-app/ |
      | https://github.com/openshift/sti-perl.git | openshift/perl:5.16 | PERL_APACHE2_RELOAD=true | sti-perl | s/fine/hotdeploy_test/g |index.pl | 5.16/test/sample-test-app/ |
