Feature: REST related features
  # @author xiaocwan@redhat.com
  # @case_id 457806
  Scenario:[origin_platformexp_397]The user should be system:anonymous user when access api without certificate and Bearer token
    Given I log the message> set up OpenShift with an identity provider that supports 'challenge: true'
    When I perform the HTTP request:
    """
    :url: <%= env.api_endpoint_url %>/oapi/v1/users/~
    :method: :get
    :headers:
      :accept: text/html
    :max_redirects: 0
    """
    Then the step should fail
    And the output should match:
      | system:anonymous.* cannot get users at the cluster scope |
      | eason.*orbidden |
    And the expression should be true> @result[:exitstatus] == 403
