Feature:Create db using new_app cmd feature
  # @author dyan@redhat.com
  # @case_id 509028, 509030
  Scenario Outline: Create mysql resources from imagestream via oc new-app
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | <image_stream_name> |
      | env          | MYSQL_USER=user,MYSQL_PASSWORD=pass,MYSQL_DATABASE=db |
    Then the step should succeed
    Given I wait for the "mysql" service to become ready
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | bash           |
      | -c             |
      | mysql -h $MYSQL_SERVICE_HOST -uuser -ppass -e "show databases" |
    Then the step should succeed
    """
    And the output should contain "db"

    When I execute on the pod:
      | bash           |
      | -c             |
      | mysql -h $MYSQL_SERVICE_HOST -uuser -ppass   -e "use db;create table test (name VARCHAR(20))" |
    Then the step should succeed
    When I execute on the pod:
      | bash           |
      | -c             |
      | mysql -h $MYSQL_SERVICE_HOST -uuser -ppass   -e "use db;insert into test VALUES('openshift')" |
    Then the step should succeed
    When I execute on the pod:
      | bash           |
      | -c             |
      | mysql -h $MYSQL_SERVICE_HOST -uuser -ppass  -e "use db;select * from test" |
    Then the output should contain:
      | name |
      | openshift |

    Examples:
      | image_stream_name |
      | mysql:5.6         |
      | mysql:5.5         |

  # @author dyan@redhat.com
  # @case_id 508979, 515707
  Scenario Outline: Create mongodb resources from imagestream via oc new-app
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | <image_stream_name> |
      | env          | MONGODB_USER=user,MONGODB_PASSWORD=pass,MONGODB_DATABASE=db,MONGODB_ADMIN_PASSWORD=pass |
    Then the step should succeed
    Given I wait for the "mongodb" service to become ready
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | bash           |
      | -c             |
      | mongo db -uuser -ppass --eval "db.db.insert({'name':'openshift'})" |
    Then the step should succeed
    """
    When I execute on the pod:
      | bash           |
      | -c             |
      | mongo db -uuser -ppass --eval "printjson(db.db.findOne())" |
    Then the step should succeed
    And the output should contain:
      | name |
      | openshift |

    Examples:
      | image_stream_name |
      | mongodb:2.6       |
      | mongodb:2.4       |
