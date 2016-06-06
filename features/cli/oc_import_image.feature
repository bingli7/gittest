Feature: oc import-image related feature
  # @author haowang@redhat.com
  # @case_id 488868
  Scenario: import an invalid image stream
    When I have a project
    And I run the :import_image client command with:
      | image_name | invalidimagename|
    Then the step should fail
    And the output should match:
      | no.*"invalidimagename" exists |

  # @author chunchen@redhat.com
  # @case_id 488870
  Scenario: [origin_infrastructure_437] Import new tags to image stream
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc488870/application-template-stibuild.json |
    Then the step should succeed
    When I run the :new_secret client command with:
      | secret_name     | sec-push                                                             |
      | credential_file | <%= expand_private_path(conf[:services, :docker_hub, :dockercfg]) %> |
    Then the step should succeed
    When I run the :add_secret client command with:
      | sa_name         | builder                     |
      | secret_name     | sec-push                    |
    Then the step should succeed
    Given a 5 character random string is stored into the :tag_name clipboard
    When I run the :new_app client command with:
      | template | python-sample-sti                   |
      | param    | OUTPUT_IMAGE_TAG=<%= cb.tag_name %> |
    When I run the :get client command with:
      | resource        | imagestreams |
    Then the output should contain "python-sample-sti"
    And the output should not contain "<%= cb.tag_name %>"
    Given the "python-sample-build-sti-1" build was created
    And the "python-sample-build-sti-1" build completed
    When I run the :import_image client command with:
      | image_name         | python-sample-sti        |
    Then the step should succeed
    When I run the :get client command with:
      | resource_name   | python-sample-sti |
      | resource        | imagestreams      |
      | o               | yaml              |
    Then the output should contain "tag: <%= cb.tag_name %>"

  # @author chaoyang@redhat.com
  # @case_id 474368
  Scenario: [origin_infrastructure_319]Do not create tags for ImageStream if image repository does not have tags
    When I have a project
    And I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/is_without_tags.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | imagestreams |
    Then the output should contain "hello-world"
    When I run the :get client command with:
      | resource_name   | hello-world  |
      | resource        | imagestreams     |
      | o               | yaml             |
    And the output should not contain "tags"

  # @author xxia@redhat.com
  # @case_id 488869
  Scenario: Import new images to image stream
    Given I have a project
    When I run the :create client command with:
      | f        | -   |
      | _stdin   | {"kind":"ImageStream","apiVersion":"v1","metadata":{"name":"my-imagestream"}} |
    Then the step should succeed

    # Creating a pod is a helper step. Without this, cucumber runs the ':create' step so fast that the imagestream is not yet ready to be referenced in ':patch' step and ':patch' will fail
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json |
    Then the step should succeed
    Given the pod named "hello-openshift" becomes ready
    When I run the :patch client command with:
      | resource      | is                      |
      | resource_name | my-imagestream          |
      | p             | {"spec":{"dockerImageRepository":"aosqe/hello-openshift"}} |
    Then the step should succeed
    When I run the :import_image client command with:
      | image_name         | my-imagestream           |
    Then the step should succeed
    And the output should match:
      | The import completed successfully           |
      | latest.+aosqe/hello-openshift@sha256:       |

  # @author wsun@redhat.com
  # @case_id 510524
  Scenario: Import image when pointing to non-existing docker image
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/wsun1/v3-testfiles/master/image-streams/tc510524.json |
    Then the step should succeed
    When I run the :import_image client command with:
      | image_name | tc510524 |
    Then the step should fail
    And the output should match:
      | the repository "aosqe/non-existen-image" was not found, tag "latest" has not been set on repository "aosqe/non-existen-image" |

  # @author wsun@redhat.com
  # @case_id 510529
  Scenario: Import Image without tags and spec.DockerImageRepository set
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/wsun1/v3-testfiles/master/image-streams/tc510529.json |
    Then the step should succeed
    When I run the :import_image client command with:
      | image_name | tc510529 |
    Then the step should fail
    And the output should match:
      | error: image stream has not defined anything to import |

  # @author xiaocwan@redhat.com
  # @case_id 519468
  Scenario: oc import-image should take the new api endpoint to run imports instead of clearing the annotation
    Given I have a project
    When I run the :tag client command with:
      | source_type | docker                 |
      | source      | hello-openshift:latest |
      | dest        | <%= project.name %>/ho:latest |
    Then the output should match:
      | [Tt]ag ho:latest |
    When I get project is as YAML
    Then the output should match:
      | annotations:\\s+openshift.io/image.dockerRepositoryCheck:|

    When I run the :import_image client command with:
      | image_name    | ho |
      | loglevel | 6  |
    Then the output should contain:
      | /oapi/v1/namespaces/<%= project.name %>/imagestreams/ho |
    When I get project is as YAML
    Then the output should match:
      | annotations:\\s+openshift.io/image.dockerRepositoryCheck:|