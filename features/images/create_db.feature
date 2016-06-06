Feature:Create apps using new_app cmd feature
  # @author wewang@redhat.com
  # @case_id 508992 508995
  Scenario Outline: Create postgresql resources from imagestream via oc new-app -postgresql-94-rhel7
    Given I have a project

    When I run the :new_app client command with:
      | image_stream |<psql_image> |
      | env |POSTGRESQL_USER=user |
      | env |POSTGRESQL_DATABASE=db |
      | env |POSTGRESQL_PASSWORD=pass |
    Then the step should succeed

    Given I wait for the "postgresql" service to become ready
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | bash |
      | -c |
    #| echo  'CREATE TABLE tbl (col1 VARCHAR(20), col2 VARCHAR(20));' \|psql -U user db |
      | psql -U user -c 'CREATE TABLE tbl (col1 VARCHAR(20), col2 VARCHAR(20));' db |
    Then the step should succeed
    """

    When I execute on the pod:
      | bash |
      | -c |
    # | echo  "INSERT INTO tbl(col1,col2) VALUES ('foo1','bar1');" \|psql db |
      | psql -U user -c "INSERT INTO tbl(col1,col2) VALUES ('foo1','bar1');" db |
    Then the step should succeed

    When I execute on the pod:
      | bash |
      | -c |
    # | echo 'select * from tbl;' \| psql db|
      | psql -U user -c 'select * from tbl;' db |

    Then the step should succeed
    And the output should contain:
      | col1 | col2 |
      | foo1 | bar1 |

    Examples:
      | psql_image |
      | openshift/postgresql:9.4 |
      | openshift/postgresql:9.2 |
