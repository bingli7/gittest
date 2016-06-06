Feature: Logging and Metrics

  # @author chunchen@redhat.com
  # @case_id 509065
  # @author xiazhao@redhat.com
  # @case_id 521420
  @admin
  @smoke
  Scenario: Access heapster interface,Check jboss wildfly version from hawkular-metrics pod logs
    Given I have a project
    And I store default router subdomain in the :subdomain clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin-metrics/master/metrics-deployer-setup.yaml |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role            |   edit |
      | user_name       |   system:serviceaccount:<%=project.name%>:metrics-deployer |
    Then the step should succeed
    Given cluster role "cluster-reader" is added to the "heapster" service account
    When I run the :new_secret client command with:
      | secret_name | metrics-deployer |
      | credential_file | nothing=/dev/null |
    Then the step should succeed
    When I create a new application with:
      | template | metrics-deployer-template |
      | param | HAWKULAR_METRICS_HOSTNAME=hawkular-metrics.<%= cb.subdomain%> |
      | param | IMAGE_PREFIX=<%= product_docker_repo %>openshift3/,USE_PERSISTENT_STORAGE=false,IMAGE_VERSION=latest |
      | param | MASTER_URL=<%= env.api_endpoint_url %> |
    Then the step should succeed
    And all pods in the project are ready
    And I wait for the "hawkular-cassandra" service to become ready
    And I wait for the "hawkular-metrics" service to become ready
    And I wait for the "heapster" service to become ready
    # sync with upstream metrics image team about desired version if this fails https://trello.com/c/ZPQN4gdp/, or contact xiazhao@redhat.com
    Given a pod becomes ready with labels:
      | metrics-infra=hawkular-metrics |
    And I wait for the steps to pass:
    """
    When I run the :logs client command with:
      | resource_name    | pods/<%= pod.name %>|
    Then the output should contain:
      | JBoss EAP 6.4.4.GA  |
    """
    Given the first user is cluster-admin
    Given I wait for the steps to pass:
    """
    When I perform the :access_heapster rest request with:
      | project_name | <%=project.name%> |
    Then the step should succeed
    """

  # @author chunchen@redhat.com
  # @case_id 509059,522124
  @admin
  @smoke
  @destructive
  Scenario: Scale up kibana and elasticsearch pods
    Given I have a project
    And I store default router subdomain in the :subdomain clipboard
    When I run the :new_secret client command with:
      | secret_name | logging-deployer |
      | credential_file | nothing=/dev/null |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc509059/sa.yaml |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role            |   edit |
      | user_name       |   system:serviceaccount:<%= project.name %>:logging-deployer |
    Then the step should succeed
    Given cluster role "cluster-reader" is added to the "aggregated-logging-fluentd" service account
    When I run the :oadm_policy_add_scc_to_user admin command with:
      | scc       | privileged      |
      | user_name | system:serviceaccount:<%= project.name %>:aggregated-logging-fluentd |
    Then the step should succeed
    Given I register clean-up steps:
    """
    I run the :oadm_policy_remove_scc_from_user admin command with:
      | scc       | privileged      |
      | user_name | system:serviceaccount:<%= project.name %>:aggregated-logging-fluentd |
    the step should succeed
    """
    When I create a new application with:
      | template | logging-deployer-template|
      | param | IMAGE_PREFIX=<%= product_docker_repo %>openshift3/,KIBANA_HOSTNAME=kibana.<%= cb.subdomain%>,PUBLIC_MASTER_URL=<%= env.api_endpoint_url %>,ES_INSTANCE_RAM=1024M,ES_CLUSTER_SIZE=1,IMAGE_VERSION=latest,MASTER_URL=<%= env.api_endpoint_url %> |
    Then the step should succeed
    Given I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource  | templates |
    Then the output should contain "logging-support-template"
    """
    And the first user is cluster-admin
    Given I register clean-up steps:
    """
    I switch to cluster admin pseudo user
    I use the "<%=project.name%>" project
    I run the :delete admin command with:
      | object_type |  oauthclients |
      | object_name_or_id |   kibana-proxy |
      | n |   <%=project.name%> |
    I wait for the resource "oauthclient" named "kibana-proxy" to disappear
    """
    When I create a new application with:
      | template | logging-support-template |
      | n | <%= project.name %> |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | imagestreams |
      | resource_name | logging-fluentd |
      | p             | {"metadata": {"annotations": {"openshift.io/image.insecureRepository": "true"}}} |
    Then the step should succeed
    When I run the :import_image client command with:
      | image_name | logging-fluentd:latest  |
      | from       | <%= product_docker_repo %>openshift3/logging-fluentd:latest |
      | insecure   | true             |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | imagestreams |
      | resource_name | logging-elasticsearch                      |
      | p             | {"metadata": {"annotations": {"openshift.io/image.insecureRepository": "true"}}} |
    Then the step should succeed
    When I run the :import_image client command with:
      | image_name | logging-elasticsearch:latest |
      | from       |  <%= product_docker_repo %>openshift3/logging-elasticsearch:latest |
      | insecure   | true             |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | imagestreams |
      | resource_name | logging-auth-proxy                     |
      | p             | {"metadata": {"annotations": {"openshift.io/image.insecureRepository": "true"}}} |
    Then the step should succeed
    When I run the :import_image client command with:
      | image_name | logging-auth-proxy:latest |
      | from       | <%= product_docker_repo %>openshift3/logging-auth-proxy:latest |
      | insecure   | true             |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | imagestreams |
      | resource_name | logging-kibana                      |
      | p             | {"metadata": {"annotations": {"openshift.io/image.insecureRepository": "true"}}} |
    Then the step should succeed
    When I run the :import_image client command with:
      | image_name | logging-kibana:latest |
      | from       | <%= product_docker_repo %>openshift3/logging-kibana:latest |
      | insecure   | true             |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource  | replicationcontrollers |
    Then the output should contain:
      | logging-fluentd-1 |
      | logging-kibana-1 |
    """
    And I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | logging-kibana-1      |
      | replicas | 2                      |
    And I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | logging-fluentd-1      |
      | replicas | 1                      |
    And I wait until number of replicas match "1" for replicationController "logging-fluentd-1"
    And I wait until number of replicas match "2" for replicationController "logging-kibana-1"
    Given a pod becomes ready with labels:
      | component=es |
    And I wait for the steps to pass:
    """
    When I run the :logs client command with:
      | resource_name    | pods/<%= pod.name %>|
    Then the output should match:
      | \[<%= project.name %>\.\w{8}-\w{4}-\w{4}-\w{4}-\w{12}\.\d{4}\.\d{2}\.\d{2}\] |
    """
