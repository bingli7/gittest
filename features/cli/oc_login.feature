Feature: oc_login.feature

  # @author cryan@redhat.com
  # @case_id 481490
  Scenario: oc login can deal with host which has trailing slash
    When I switch to the first user
    When I run the :login client command with:
      | server   | https://<%= env.master_hosts[0].hostname %>:8443/ |
      | u | <%= @user.name %>     |
      | p | <%= @user.password %> |
    Then the step should succeed
    And the output should match "Login successful|Logged into"

  # @author xiaocwan@redhat.com
  # @case_id 476303
  Scenario: User can login with the new generated token via web page for oc
    Given I log the message> this scenario can pass only when user accounts have a known password
    When I perform the :request_token_with_password web console action with:
      | url    | <%= env.api_endpoint_url %>/oauth/token/request |
      | username  | <%= user(0, switch: false).name %>    |
      | password |  <%= user(0, switch: false).password %>   |
      | _nologin | |
    Then the step should succeed
    When I get the content of the "element" web element:
      | xpath | //code |
    And I run the :login client command with:
      | server   | <%= env.api_endpoint_url %> |
      | token | <%= @result[:response].split(">")[1].split("<")[0] %>   |
    Then the step should succeed

  # @author xiaocwan@redhat.com
  # @case_id 510552
  Scenario: Logout of the active session by clearing saved tokens
    Given I log the message> this scenario can pass only when user accounts have a known password
    When I run the :login client command with:
      | server   | <%= env.api_endpoint_url %> |
      | u | <%= user.name %>     |
      | p | <%= user.password %> |
      | config   | dummy.kubeconfig |
      | insecure | true |
    Then the step should succeed
    When I run the :config client command with:
      | subcommand | view |
      | config   | dummy.kubeconfig |
    Then the step should succeed
    And the output should contain "token"
    And evaluation of `@result[:response].split("token: ")[1].strip()` is stored in the :token clipboard
    When I run the :get client command with:
      | resource | project |
      | token    | <%= cb.token %>  |
      | config   | dummy.kubeconfig |
    Then the step should succeed

    When I run the :logout client command with:
      | config   | dummy.kubeconfig |
    Then the step should succeed
    When I run the :config client command with:
      | subcommand | view |
      | config   | dummy.kubeconfig |
    Then the step should succeed
    And the output should not contain "token"
    When I run the :get client command with:
      | resource | project |
      | token    | <%= cb.token %>  |
      | config   | dummy.kubeconfig |
    Then the step should fail

  # @author pruan@redhat.com
  # @case_id 476032
  Scenario: Warning should be displayed when login failed via oc login
    When I run the :login client command with:
      | u | <% "" %>            |
      | p | <% user.password %> |
    Then the step should fail
    Then the output should contain "Login failed"
    Given a 5 characters random string is saved into the :rand_str clipboard
    When I run the :login client command with:
      | u | <% user.name %>     |
      | p | <% @cb[:rand_str %> |
    Then the step should fail
    Then the output should contain "Login failed"
    When I run the :login client command with:
      | token | <% @cb[:rand_str %> |
    Then the step should fail
    Then the output should contain "The token provided is invalid or expired"
