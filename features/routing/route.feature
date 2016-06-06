Feature: Testing route

  # @author: zzhao@redhat.com
  # @case_id: 470698
  Scenario: Be able to add more alias for service
    Given I have a project
    When I run the :create client command with:
      | f  |  https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/header-test/dc.json |
    Then the step should succeed
    When I run the :create client command with:
      | f  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/header-test/insecure-service.json |
    Then the step should succeed
    When I expose the "header-test-insecure" service
    Then the step should succeed
    And I wait for a web server to become available via the route
    When I run the :get client command with:
      | resource      | route |
      | resource_name | header-test-insecure |
      | o             | yaml |
    And I save the output to file>header-test-insecure.yaml
    And I replace lines in "header-test-insecure.yaml":
      | name: header-test-insecure | name: header-test-insecure-dup |
      | host: header-test-insecure | host: header-test-insecure-dup |
    When I run the :create client command with:
      |f | header-test-insecure.yaml |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | route                                           |
      | resource_name | header-test-insecure-dup                        |
      | p             | {"spec":{"to":{"name":"header-test-insecure"}}} |
    Then I wait for a web server to become available via the "header-test-insecure-dup" route

  # @author: zzhao@redhat.com
  # @case_id: 470700
  Scenario: Alias will be invalid after removing it
    Given I have a project
    When I run the :create client command with:
      | f  |   https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/header-test/dc.json  |
    Then the step should succeed
    When I run the :create client command with:
      | f  |   https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/header-test/insecure-service.json |
    Then the step should succeed
    When I expose the "header-test-insecure" service
    Then the step should succeed
    Then I wait for a web server to become available via the "header-test-insecure" route
    When I run the :delete client command with:
      | object_type | route |
      | object_name_or_id | header-test-insecure |
    Then I wait for the resource "route" named "header-test-insecure" to disappear
    Then I wait up to 20 seconds for the steps to pass:
    """
    When I open web server via the "header-test-insecure" route
    Then the step should fail
    """

  # @author xxia@redhat.com
  # @case_id 483200
  @admin
  Scenario: The certs for the edge/reencrypt termination routes should be removed when the routes removed
    Given I switch to cluster admin pseudo user
    And I use the "default" project
    And a pod becomes ready with labels:
      | deploymentconfig=router |
    Then evaluation of `pod.name` is stored in the :router_pod clipboard

    Given I switch to the first user
    And I have a project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt.json" replacing paths:
      | ["spec"]["host"]  | www.<%= rand_str(5, :dns) %>.example.com |
    Then the step should succeed
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/route_edge.json" replacing paths:
      | ["spec"]["host"]  | www.<%= rand_str(5, :dns) %>.example.com |
    Then the step should succeed

    Then evaluation of `project.name` is stored in the :proj_name clipboard
    And evaluation of `"secured-edge-route"` is stored in the :edge_route clipboard
    And evaluation of `"route-reencrypt"` is stored in the :reencrypt_route clipboard

    When I switch to cluster admin pseudo user
    And I use the "default" project
    And I execute on the "<%= cb.router_pod %>" pod:
      | ls                  |
      | /var/lib/containers/router/certs |
    Then the step should succeed
    And the output should contain:
      | <%= cb.proj_name %>_<%= cb.edge_route %>.pem |
      | <%= cb.proj_name %>_<%= cb.reencrypt_route %>.pem |
    When I execute on the pod:
      | ls                  |
      | /var/lib/containers/router/cacerts |
    Then the step should succeed
    And the output should contain:
      | <%= cb.proj_name %>_<%= cb.reencrypt_route %>.pem |

    Given I switch to the first user
    And I use the "<%= cb.proj_name %>" project
    When I run the :delete client command with:
      | object_type       | route                |
      | object_name_or_id | <%= cb.edge_route %> |
    Then the step should succeed

    When I wait for the resource "route" named "<%= cb.edge_route %>" to disappear
    And I switch to cluster admin pseudo user
    And I use the "default" project
    And I execute on the pod:
      | ls                  |
      | /var/lib/containers/router/certs |
    Then the step should succeed
    And the output should not contain:
      | <%= cb.proj_name %>_<%= cb.edge_route %>.pem |
    And the output should contain:
      | <%= cb.proj_name %>_<%= cb.reencrypt_route %>.pem |

    Given I switch to the first user
    And I use the "<%= cb.proj_name %>" project
    When I run the :delete client command with:
      | object_type       | route                     |
      | object_name_or_id | <%= cb.reencrypt_route %> |
    Then the step should succeed

    When I wait for the resource "route" named "<%= cb.reencrypt_route %>" to disappear
    And I switch to cluster admin pseudo user
    And I use the "default" project
    And I execute on the pod:
      | ls                  |
      | /var/lib/containers/router/certs   |
      | /var/lib/containers/router/cacerts |
    Then the step should succeed
    And the output should not contain:
      | <%= cb.proj_name %>_<%= cb.reencrypt_route %>.pem |

  # @author yadu@redhat.com
  # @case_id 497886
  Scenario: Service endpoint can be work well if the mapping pod ip is updated
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/list_for_pods.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :get client command with:
      | resource | endpoints |
    And the output should contain:
      | test-service |
      | :8080        |
    When I get project replicationcontroller as JSON
    And evaluation of `@result[:parsed]['items'][0]['metadata']['name']` is stored in the :rc_name clipboard
    Then I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | <%= cb.rc_name %>      |
      | replicas | 0                      |
    When I run the :get client command with:
      | resource | endpoints |
    And the output should contain:
      | test-service |
      | none         |
    Then I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | <%= cb.rc_name %>      |
      | replicas | 1                      |
    And I wait until number of replicas match "1" for replicationController "<%= cb.rc_name %>"
    And all pods in the project are ready
    When I run the :get client command with:
      | resource | endpoints |
    And the output should contain:
      | test-service |
      | :8080        |

  # @author: zzhao@redhat.com
  # @case_id: 516833
  Scenario: Check the header forward format
    Given I have a project
    When I run the :create client command with:
      | f  |  https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/header-test/dc.json |
    Then the step should succeed
    When I run the :create client command with:
      | f  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/header-test/insecure-service.json |
    Then the step should succeed
    When I expose the "header-test-insecure" service
    Then the step should succeed
    When I wait for a web server to become available via the route
    Then the output should contain ";host=<%= route.dns(by: user) %>;proto=http"



  # @author: yadu@redhat.com
  # @case_id: 511645 
  Scenario: Config insecureEdgeTerminationPolicy to an invalid value for route
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/example_wildcard.pem"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/example_wildcard.key"
    When I run the :create_route_edge client command with:
      | name     | myroute      |
      | hostname | <%= rand_str(5, :dns) %>-edge.example.com |
      | service  | service-unsecure |
      | cert | example_wildcard.pem |
      | key | example_wildcard.key |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | route |
      | resource_name | myroute |
      | p             | {"spec":{"tls":{"insecureEdgeTerminationPolicy":"Abc"}}} |
    And the output should contain:
      | invalid value for InsecureEdgeTerminationPolicy option, acceptable values are None, Allow, Redirect, or empty |

 
  # @author: zzhao@redhat.com
  # @case_id: 500002
  Scenario: The later route should be HostAlreadyClaimed when there is a same host exist
    Given I have a project
    When I run the :create client command with:
      | f |  https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/route_unsecure.json  |
    Then the step should succeed
    Given I create a new project
    When I run the :create client command with:
      | f |  https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/route_unsecure.json  |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | route  |
      | resource_name | route  |
    Then the output should contain "HostAlreadyClaimed"

    
  # @author bmeng@redhat.com
  # @case_id 470715
  Scenario: Edge terminated route with custom cert
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/route_edge-www.edge.com.crt"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/route_edge-www.edge.com.key"
    
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/pod-for-ping.json |
    And the pod named "hello-pod" becomes ready
    Given I execute on the "<%= pod.name %>" pod:
      | wget |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/ca.pem |
      | -O |
      | /tmp/ca.pem |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name | route-edge |
      | hostname | www.edge.com |
      | service | service-unsecure |
      | cert | route_edge-www.edge.com.crt |
      | key | route_edge-www.edge.com.key |
    Then the step should succeed
    When I execute on the "<%= pod.name %>" pod:
      | curl |
      | --resolve |
      | www.edge.com:443:<%= cb.router_ip[0] %> |
      | https://www.edge.com/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the output should contain "Hello-OpenShift"


  # @author bmeng@redhat.com
  # @case_id 470716
  Scenario: Passthrough terminated route with custom cert
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/passthrough/service_secure.json |
    Then the step should succeed
    
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/pod-for-ping.json |
    And the pod named "hello-pod" becomes ready
    Given I execute on the "<%= pod.name %>" pod:
      | wget |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/ca.pem |
      | -O |
      | /tmp/ca.pem |
    Then the step should succeed
    When I run the :create_route_passthrough client command with:
      | name | passthrough-route |
      | hostname | www.example.com |
      | service | service-secure |
    Then the step should succeed
    When I execute on the "<%= pod.name %>" pod:
      | curl |
      | --resolve |
      | www.example.com:443:<%= cb.router_ip[0] %> |
      | https://www.example.com/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the output should contain "Hello-OpenShift"


  # @author bmeng@redhat.com
  # @case_id 470717
  Scenario: Reencrypt terminated route with custom cert
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/service_secure.json |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt-reen.example.com.crt"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt-reen.example.com.key"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt.ca"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt_dest.ca"

    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/pod-for-ping.json |
    And the pod named "hello-pod" becomes ready
    Given I execute on the "<%= pod.name %>" pod:
      | wget |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/ca.pem |
      | -O |
      | /tmp/ca.pem |
    Then the step should succeed 
    When I run the :create_route_reencrypt client command with:
      | name | route-recrypt |
      | hostname | reen.example.com |
      | service | service-secure |
      | cert | route_reencrypt-reen.example.com.crt |
      | key | route_reencrypt-reen.example.com.key |
      | cacert | route_reencrypt.ca |
      | destcacert | route_reencrypt_dest.ca |
    Then the step should succeed
    When I execute on the "<%= pod.name %>" pod:
      | curl |
      | --resolve |
      | reen.example.com:443:<%= cb.router_ip[0] %> |
      | https://reen.example.com/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the output should contain "Hello-OpenShift"

  # @author zzhao@redhat.com
  # @case_id 470736
  Scenario: The path specified in route can work well for unsecure
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    When I run the :expose client command with:
      | resource     | svc |
      | resource_name| service-unsecure |
      | path         | /test |
    When I open web server via the "http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/test/" url
    Then the output should contain "Hello-OpenShift-Path-Test"
    When I open web server via the "http://<%= route("service-unsecure", service("service-unsecure")).dns(by: user) %>/" url
    Then the step should fail

  # @author zzhao@redhat.com
  # @case_id 470735
  Scenario: The path specified in route can work well for edge terminated
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/route_edge-www.edge.com.crt"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/edge/route_edge-www.edge.com.key"

    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/pod-for-ping.json |
    And the pod named "hello-pod" becomes ready
    Given I execute on the "<%= pod.name %>" pod:
      | wget |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/ca.pem |
      | -O |
      | /tmp/ca.pem |
    Then the step should succeed
    When I run the :create_route_edge client command with:
      | name | edge-route |
      | hostname | <%= rand_str(5, :dns) %>-edge.example.com |
      | service | service-unsecure |
      | cert | route_edge-www.edge.com.crt |
      | key | route_edge-www.edge.com.key |
      | path| /test |
    Then the step should succeed
    When I execute on the "<%= pod.name %>" pod:
      | curl |
      | --resolve |
      | <%= route("edge-route", service("edge-route")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/test/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the output should contain "Hello-OpenShift-Path-Test"
    When I execute on the "<%= pod.name %>" pod:
      | curl |
      | --resolve |
      | <%= route("edge-route", service("edge-route")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("edge-route", service("edge-route")).dns(by: user) %>/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the output should contain "Application is not available"

  # @author zzhao@redhat.com
  # @case_id 498581
  Scenario: The path specified in route can work well for reencrypt terminated
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/service_secure.json |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt-reen.example.com.crt"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt-reen.example.com.key"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt.ca"
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt_dest.ca"

    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/pod-for-ping.json |
    And the pod named "hello-pod" becomes ready
    Given I execute on the "<%= pod.name %>" pod:
      | wget |
      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/ca.pem |
      | -O |
      | /tmp/ca.pem |
    Then the step should succeed
    When I run the :create_route_reencrypt client command with:
      | name | route-recrypt |
      | hostname | <%= rand_str(5, :dns) %>-reen.example.com |
      | service | service-secure |
      | cert | route_reencrypt-reen.example.com.crt |
      | key | route_reencrypt-reen.example.com.key |
      | cacert | route_reencrypt.ca |
      | destcacert | route_reencrypt_dest.ca |
      | path | /test |
    Then the step should succeed
    When I execute on the "<%= pod.name %>" pod:
      | curl |
      | --resolve |
      | <%= route("route-recrypt", service("route-recrypt")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-recrypt", service("route-recrypt")).dns(by: user) %>/test/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the output should contain "Hello-OpenShift-Path-Test"
    When I execute on the "<%= pod.name %>" pod:
      | curl |
      | --resolve |
      | <%= route("route-recrypt", service("route-recrypt")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("route-recrypt", service("route-recrypt")).dns(by: user) %>/ |
      | --cacert |
      | /tmp/ca.pem |
    Then the output should contain "Application is not available"

  # @author zzhaoe@redhat.com
  # @case_id 483186
  Scenario: Re-encrypting route with no cert if a router is configured with a default wildcard cert
    Given I have a project
    And I store default router IPs in the :router_ip clipboard
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/service_secure.json |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/reencrypt/route_reencrypt_dest.ca"
    And the step should succeed
   
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/pod-for-ping.json |
    And the pod named "hello-pod" becomes ready
    When I run the :create_route_reencrypt client command with:
      | name | no-cert |
      | hostname | <%= rand_str(5, :dns) %>-reen.example.com |
      | service | service-secure |
      | destcacert | route_reencrypt_dest.ca |
    Then the step should succeed
    When I execute on the "<%= pod.name %>" pod:
      | curl |
      | --resolve |
      | <%= route("no-cert", service("no-cert")).dns(by: user) %>:443:<%= cb.router_ip[0] %> |
      | https://<%= route("no-cert", service("no-cert")).dns(by: user) %>/ |
      | -k |
    Then the output should contain "Hello-OpenShift"

  # @author yadu@redhat.com
  # @case_id 470732
  Scenario: Create a route without host named
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/caddy-docker.json |
    Then the step should succeed
    And all pods in the project are ready
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/unsecure/service_unsecure.json |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/tc/tc470732/route_withouthost1.json |
    Then the step should succeed
    When I use the "service-unsecure" service
    Then I wait for a web server to become available via the "service-unsecure1" route
    Then the output should contain "Hello-OpenShift"
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/tc/tc470732/route_withouthost2.json |
    Then the step should succeed
    When I use the "service-unsecure" service
    Then I wait for a web server to become available via the "service-unsecure2" route
    Then the output should contain "Hello-OpenShift"
