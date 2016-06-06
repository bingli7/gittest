Feature: new-app with --search option
  # @author yanpzhan@redhat.com
  # @case_id 497510
  Scenario: Command oc new-app should support search function
    Given I have a project
    And I run the :create client command with:
      |f| https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-centos7.json|
    Then the step should succeed
    And I run the :create client command with:
      |f| https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json|
    Then the step should succeed
    And I run the :create client command with:
      |f| https://raw.githubusercontent.com/openshift/origin/master/examples/db-templates/mysql-persistent-template.json|
    Then the step should succeed
    And I run the :create client command with:
      |f| https://raw.githubusercontent.com/openshift/origin/master/examples/db-templates/mongodb-ephemeral-template.json|
    Then the step should succeed
    When I run the :new_app client command
    Then the output should contain:
      | $ oc new-app -S php |
      | $ oc new-app -S --template=ruby |
      | $ oc new-app -S --image=mysq |

    #Search directly
    When I run the :new_app client command with:
      | search | true |
      | app_repo | ruby |
    Then the step should succeed
    And the output should contain:
      |Templates (oc new-app --template=<template>)|
      |ruby-helloworld-sample|
      |Project: <%= project.name %>|
      |This example shows how to create a simple ruby application in openshift origin v3|
      |Image streams (oc new-app --image-stream=<image-stream> [--code=<source>])|
      |ruby|
      |Project: <%= project.name %>|
      |Docker images (oc new-app --docker-image=<docker-image> [--code=<source>])|
      |ruby|
      |Registry: Docker Hub|

    #Search by --docker-image
    When I run the :new_app client command with:
      | search | true |
      | docker_image | mysql |
    Then the step should succeed
    And the output should contain:
      |Docker images (oc new-app --docker-image=<docker-image> [--code=<source>])|
      |mysql|
      |Registry: Docker Hub|
    When I run the :new_app client command with:
      | search | true |
      | docker_image | ruby |
    Then the step should succeed
    And the output should contain:
      |Docker images (oc new-app --docker-image=<docker-image> [--code=<source>])|
      |ruby|
      |Registry: Docker Hub|

    #Search by --image-stream
    When I run the :new_app client command with:
      | search | true |
      | image_stream | mysql |
    Then the step should succeed
    And the output should contain:
      |Image streams (oc new-app --image-stream=<image-stream> [--code=<source>])|
      |mysql|
      |Project: <%= project.name %>|

    When I run the :new_app client command with:
      | search | true |
      | image_stream | ruby |
    Then the step should succeed
    And the output should contain:
      |Image streams (oc new-app --image-stream=<image-stream> [--code=<source>])|
      |ruby|
      |Project: <%= project.name %>|

    #Search by --template
    When I run the :new_app client command with:
      | search | true |
      | template | ruby |
    Then the step should succeed
    And the output should contain:
      |Templates (oc new-app --template=<template>)|
      |ruby-helloworld-sample|
      |Project: <%= project.name %>|
      |This example shows how to create a simple ruby application in openshift origin v3|
    When I run the :new_app client command with:
      | search | true |
      | template | mysql |
    Then the step should succeed
    And the output should contain:
      |Templates (oc new-app --template=<template>)|
      |mysql-persistent|
      |Project: <%= project.name %>|
      |MySQL database service, with persistent storage.|
      |Scaling to more than one replica is not supported|
    When I run the :new_app client command with:
      | search | true |
      | template | mongodb |
    Then the step should succeed
    And the output should contain:
      |Templates (oc new-app --template=<template>)|
      |mongodb-ephemeral|
      |Project: <%= project.name %>|
      |MongoDB database service, without persistent storage. WARNING: Any data stored will be lost upon pod destruction. Only use this template for testing|

    #Search with --docker-image, --image-stream, --template together
    When I run the :new_app client command with:
      | search | true |
      | docker_image | ruby |
      | image_stream | php |
      | template | mysql |
    Then the step should succeed
    And the output should contain:
      |Templates (oc new-app --template=<template>)|
      |mysql-persistent|
      |Project: <%= project.name %>|
      |MySQL database service, with persistent storage.|
      |Scaling to more than one replica is not supported|
      |Image streams (oc new-app --image-stream=<image-stream> [--code=<source>])|
      |php|
      |Project: <%= project.name %>|
      |Docker images (oc new-app --docker-image=<docker-image> [--code=<source>])|
      |ruby|
      |Registry: Docker Hub|

    When I run the :new_app client command with:
      | search | true |
      | image_stream | php |
      | template | mysql |
    Then the step should succeed
    And the output should contain:
      |Templates (oc new-app --template=<template>)|
      |mysql-persistent|
      |Project: <%= project.name %>|
      |MySQL database service, with persistent storage.|
      |Scaling to more than one replica is not supported|
      |Image streams (oc new-app --image-stream=<image-stream> [--code=<source>])|
      |php|
      |Project: <%= project.name %>|

    #Search with partial match
    When I run the :new_app client command with:
      | search | true |
      | app_repo | ru |
    Then the step should succeed
    And the output should contain:
      |Templates (oc new-app --template=<template>)|
      |ruby-helloworld-sample|
      |Project: <%= project.name %>|
      |This example shows how to create a simple ruby application in openshift origin v3|
      |Image streams (oc new-app --image-stream=<image-stream> [--code=<source>])|
      |ruby|
      |Project: <%= project.name %>|
    When I run the :new_app client command with:
      | search | true |
      | image_stream | ph |
    Then the step should succeed
    And the output should contain:
      |Image streams (oc new-app --image-stream=<image-stream> [--code=<source>])|
      |php|
      |Project: <%= project.name %>|
    When I run the :new_app client command with:
      | search | true |
      | template | sql |
    Then the step should succeed
    And the output should contain:
      |Templates (oc new-app --template=<template>)|
      |mysql-persistent|
      |Project: <%= project.name %>|
      |MySQL database service, with persistent storage.|
      |Scaling to more than one replica is not supported|

  # @author pruan@redhat.com
  # @case_id 497511
  Scenario: Negative test on oc new-app with --search
    Given I have a project
    When I run the :new_app client command with:
      | h | true |
    Then the output should contain "--search"
    When I run the :new_app client command with:
      | search_raw | eap |
    Then the output should not contain "<%= project.name %>"
    When I run the :new_app client command with:
      | search_raw |  |
      | docker_image | mysql |
    Then the output should not contain "<%= project.name %>"
    When I run the :new_app client command with:
      | search_raw |  |
      | image_stream | mongodb |
    Then the output should not contain "<%= project.name %>"
    When I run the :new_app client command with:
      | search_raw | |
      | template | ruby |
    Then the output should not contain "<%= project.name %>"
    When I run the :new_app client command with:
      | search_raw | |
    Then the step should fail
    And the output should contain:
      | error: You must specify one or more images, image streams, templates, or source code locations to create an application. |
    When I run the :new_app client command with:
      | search_raw | --docker-image |
      | config | :false |
    Then the step should fail
    And the output should contain:
      | Error: flag needs an argument: --docker-image |
    When I run the :new_app client command with:
      | search_raw | --image-stream |
      | config | :false |
    Then the step should fail
    And the output should contain:
      | Error: flag needs an argument: --image-stream |
    When I run the :new_app client command with:
      | search_raw| --template |
      | config | :false |
    Then the step should fail
    And the output should contain:
      | Error: flag needs an argument: --template |
    When I run the :new_app client command with:
      | search_raw | xxxyyyy |
    Then the step should fail
    And the output should contain:
      | no matches found |
    When I run the :new_app client command with:
      | search_raw | --docker-image=deadbeef123 |
    Then the step should fail
    And the output should contain:
      | no matches found |
    When I run the :new_app client command with:
      | search_raw | --image-stream=deadbeef123 |
    Then the step should fail
    And the output should contain:
      | no matches found |
    When I run the :new_app client command with:
      | search_raw | --template=deadbeef123 |
    Then the step should fail
    And the output should contain:
      | no matches found |
    When I run the :new_app client command with:
      | search_raw | ruby |
      | code   | https://github.com/openshift/ruby-hello-world |
      | env    | path=/etc                                     |
      | param  | name=test                                     |
    Then the step should fail
    And the output should contain:
      |  --search can't be used with source code |
      |  --search can't be used with --env       |
      |  --search can't be used with --param     |
    When I run the :new_app client command with:
      | search_raw | --template=ruby |
      | code   | https://github.com/openshift/ruby-hello-world |
      | env    | path=/etc                                     |
      | param  | name=test                                     |
    Then the step should fail
    And the output should contain:
      |  --search can't be used with source code |
      |  --search can't be used with --env       |
      |  --search can't be used with --param     |
    When I run the :new_app client command with:
      | search_raw | --image-stream=mongodb |
      | code   | https://github.com/openshift/ruby-hello-world |
      | env    | path=/etc                                     |
      | param  | name=test                                     |
    Then the step should fail
    And the output should contain:
      |  --search can't be used with source code |
      |  --search can't be used with --env       |
      |  --search can't be used with --param     |
    When I run the :new_app client command with:
      | search_raw |  --docker-image=ruby |
      | code   | https://github.com/openshift/ruby-hello-world |
      | env    | path=/etc                                     |
      | param  | name=test                                     |
    Then the step should fail
    And the output should contain:
      |  --search can't be used with source code |
      |  --search can't be used with --env       |
      |  --search can't be used with --param     |

