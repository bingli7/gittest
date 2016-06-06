Feature: dockerbuild.feature
  # @author wewang@redhat.com
  # @case_id 512257
  # @case_id 512256
  @admin
  Scenario Outline: Store commit id in sti build
    Given I have a project
    When I download a file from "<file>"
    Then the step should succeed
    And I replace lines in "<file_name>":
      | registry.access.redhat.com/ | <%= product_docker_repo %> |
    Then the step should succeed
    When I run the :new_app client command with:
      | file  | <file_name> |
    Then the step should succeed
    Given the "ruby22-sample-build-1" build was created
    And the "ruby22-sample-build-1" build completed
    When I run the :describe client command with:
      | resource        | build                       |
      | name            | ruby22-sample-build-1       |
    Then the output should match:
      | Commit:.*[a-zA-Z0-9]+                         |
      | Output to:.*ImageStreamTag origin-ruby22-sample:latest |

    When I replace resource "bc" named "ruby22-sample-build":
      | github.com/openshift/ruby-hello-world.git | github.com/v3test/ruby-hello-world.git |
    Then the step should succeed
    And the output should contain "replaced"
    When I run the :get client command with:
      | resource | buildconfig  |
      | resource_name  | ruby22-sample-build |
      | o     | json  |
    Then the output should contain:
      |github.com/v3test/ruby-hello-world.git|
    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    And the "ruby22-sample-build-2" build was created
    And the "ruby22-sample-build-2" build completed
    When I run the :describe client command with:
      | resource        | build                       |
      | name            | ruby22-sample-build-2       |
    Then the output should match:
      | Commit:.*[a-zA-Z0-9]+                         |
      | Output to:.*ImageStreamTag origin-ruby22-sample:latest |

    When I run the :patch client command with:
      | resource      | bc                      |
      | resource_name | ruby22-sample-build       |
      | p             | {"spec":{"output":{"to":{"kind":"DockerImage"}}}} |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | bc                 |
      | resource_name | ruby22-sample-build  |
      | template      | {{.spec.output.to.kind}} |
    Then the step should succeed
    And the output should contain "DockerImage"

    When I run the :get admin command with:
      | resource      | service                 |
      | resource_name | docker-registry         |
      | template      | {{.spec.clusterIP}} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :host_yaml clipboard
    When I run the :patch client command with:
      | resource      | bc                      |
      | resource_name | ruby22-sample-build     |
      | p             |{"spec":{"output":{"to":{"name":"<%= cb.host_yaml %>"}}}} |
    Then the step should succeed

    When I run the :get admin command with:
      | resource      | service                 |
      | resource_name | docker-registry         |
      | template      | {{.spec.clusterIP}} |
    Then the step should succeed
    And the output should contain "<%= cb.host_yaml %>"

    When I run the :get admin command with:
      | resource      | service                 |
      | resource_name | docker-registry         |
      | template      | {{(index .spec.ports 0).port}} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :port_yaml clipboard

    When I run the :patch client command with:
      | resource      | bc                      |
      | resource_name | ruby22-sample-build     |
      | p             |{"spec":{"output":{"to":{"name":"<%= cb.host_yaml %>:<%= cb.port_yaml %>/<%= project.name %>/origin-ruby22-sample"}}}} |
    Then the step should succeed

    When I run the :get client command with:
      | resource      | bc                 |
      | resource_name | ruby22-sample-build  |
      | o             |yaml |
    And the output should contain "<%= cb.host_yaml %>:<%= cb.port_yaml %>"
    Then the step should succeed

    When I run the :start_build client command with:
      | buildconfig | ruby22-sample-build |
    And the "ruby22-sample-build-3" build was created
    And the "ruby22-sample-build-3" build completed
    When I run the :describe client command with:
      | resource        | build                       |
      | name            | ruby22-sample-build-3       |
    Then the output should match:
      | Commit:.*[a-zA-Z0-9]+                         |
      | Output to:.*DockerImage.*                     |

    Examples:
      | file                                                  |   file_name                              |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-docker.json   | ruby22rhel7-template-docker.json  |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby22rhel7-template-sti.json      | ruby22rhel7-template-sti.json     |

