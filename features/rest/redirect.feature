Feature: REST features

  # @author akostadi@redhat.com
  # @case_id 472567
  Scenario: [origin_platformexp_373] The response for root path should depend on the Accept http header
    When I perform the HTTP request:
    """
    :url: <%= env.api_endpoint_url %>/
    :method: :get
    :headers:
      :accept: text/html
    :max_redirects: 1
    """
    Then the step should succeed
    And the output should contain "OpenShift Web Console"
    When I perform the HTTP request:
    """
    :url: <%= env.api_endpoint_url %>/
    :method: :get
    :headers:
      :accept: text/html
    :max_redirects: 0
    """
    Then the step should fail
    And the expression should be true> @result[:exitstatus] == 302
    And the expression should be true> @result[:headers]["location"][0].end_with?("/console/")
    When I perform the HTTP request:
    """
    :url: <%= env.api_endpoint_url %>/
    :method: :get
    :max_redirects: 0
    """
    Then the step should succeed
    And the expression should be true> JSON.load(@result[:response])["paths"]

  # @author xiaocwan@redhat.com
  # @case_id 476029
  Scenario: [origin_platformexp_397] The basic challenge will be shown when user pass the X-CSRF-TOKEN http header
    Given I log the message> set up OpenShift with an identity provider that supports 'challenge: true'
    When I perform the HTTP request:
    """
    :url: <%= env.api_endpoint_url %>/oauth/authorize?response_type=token&client_id=openshift-challenging-client
    :method: :get
    :headers:
      :accept: text/html
    :max_redirects: 0
    """
    Then the step should fail
    And the expression should be true> @result[:exitstatus] == 401
    And the expression should be true> @result[:headers]["warning"][0].include?("X-CSRF-Token header is required")

    When I perform the HTTP request:
    """
    :url: <%= env.api_endpoint_url %>/oauth/authorize?response_type=token&client_id=openshift-challenging-client
    :method: :get
    :headers:
      :accept: text/html
      :X-CSRF-Token: 1
    :max_redirects: 0
    """
    Then the step should fail
    And the expression should be true> @result[:exitstatus] == 401
    And the expression should be true> @result[:headers].include?("www-authenticate")