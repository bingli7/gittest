Feature: Webhook REST Related Tests

  # @author cryan@redhat.com
  # @case_id 438843 438845
  Scenario Outline: Trigger build with webhook
    Given I have a project
    And I process and create "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/build/ruby20rhel7-template-sti.json"
    Given the "ruby-sample-build-1" build was created
    When I run the :patch client command with:
      | resource | buildconfig |
      | resource_name | ruby-sample-build |
      | p | {"spec": {"triggers": [{"type": "<type>","<type>": {"secret": "secret101"}}]}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | buildconfig |
      | name | ruby-sample-build |
    Then the output should not contain "<negative1>"
    Then the output should not contain "<negative2>"
    Given I download a file from "https://raw.githubusercontent.com/openshift/origin/master/pkg/build/webhook/<path><file>"
    And I replace lines in "<file>":
      | 9bdc3a26ff933b32f3e558636b58aea86a69f051 ||
    When I perform the HTTP request:
    """
    :url: <%= env.api_endpoint_url %>/oapi/v1/namespaces/<%= project.name %>/buildconfigs/ruby-sample-build/webhooks/secret101/<type>
    :method: post
    :headers:
      :Content-Type: application/json
      :<header1>: <header2>
    :payload: <file>
    """
    Then the step should succeed
    Given the "ruby-sample-build-2" build was created
    Given the "ruby-sample-build-2" build completes
    Given a pod becomes ready with labels:
      | deployment=frontend-2 |
    When I perform the HTTP request:
    """
    :url: <%= env.api_endpoint_url %>/oapi/v1/namespaces/<%= project.name %>/buildconfigs/ruby-sample-build/webhooks/secret101/<negative3>
    :method: post
    :headers:
      :Content-Type: application/json
    :payload: <file>
    """
    Then the step should fail
    Then the output should contain "not accept"
    Examples:
      | type    | negative1 | negative2   | negative3 | path              | file              | header1        | header2 |
      | generic | GitHub    | ImageChange | github    | generic/fixtures/ | push-generic.json |                |         |
      | github  | Generic   | ImageChange | generic   | github/fixtures/  | pushevent.json    | X-Github-Event | push    |
