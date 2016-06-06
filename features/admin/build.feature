Feature: admin build related features

  # @author cryan@redhat.com
  # @author akostadi@redhat.com
  # @case_id 489295
  @admin
  Scenario: Check the default option value for command oadm prune builds
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    Then the step should succeed
    When I run the :new_app client command with:
      | template | ruby-helloworld-sample|
    Then the step should succeed

    #Generate enough builds for the oadm command to clean
    Given the "ruby-sample-build-1" build was created
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed

    When I run the :oadm_prune_builds client command with:
      | h ||
    Then the step should succeed
    And the output should contain:
      | --keep-younger-than=1h                    |
      | --keep-failed=1                           |
      | --keep-complete=5                         |
      | --orphans=false                           |
    #Wait for the builds to finish:
    Given the "ruby-sample-build-1" build finished
    And the "ruby-sample-build-2" build finished
    And the "ruby-sample-build-3" build finished
    And the "ruby-sample-build-4" build finished
    And the "ruby-sample-build-5" build finished
    And the "ruby-sample-build-6" build finished
    And the "ruby-sample-build-7" build finished
    And the "ruby-sample-build-8" build finished

    # check default keep-younger option is more than 1 minute
    When I run the :oadm_prune_builds admin command
    Then the step should succeed
    And the output should not match:
      | <%= project.name %>\\s*ruby-sample-build- |

    # wait 60 sec so we can check the keep younger option
    Given 60 seconds have passed
    When I run the :oadm_prune_builds admin command with:
      | keep_younger_than | 1m |
    Then the step should succeed
    And the output should match:
      | Dry run |
      # make sure we match only builds for current project
      # some builds will succeed, some will fail so can't match exact numbers
      | <%= project.name %>\\s*ruby-sample-build- |
    And I save pruned builds in the "<%= project.name %>" project into the :pruned1 clipboard

    When I save project builds into the :builds_all clipboard
    # get the builds non-selected for prunning
    And evaluation of `cb.builds_all - cb.pruned1` is stored in the :builds clipboard
    # non-selected completed builds are <= 5
    Then the expression should be true> cb.builds.select{|b| b.status?(user: user, status: :complete)[:success]}.size <= 5
    # non-selected failed builds are <= 1
    And the expression should be true> cb.builds.select{|b| b.status?(user: user, status: [:failed, :error, :cancelled])[:success]}.size <= 1

    # Given I log the message> keep calm and get a coffee, waiting one hour to check default --keep-younger-than option
    # And 3600 seconds have passed
    # When I run the :oadm_prune_builds admin command
    # Then the step should succeed
    # And the output should match:
    #   | <%= project.name %>\\s*ruby-sample-build- |
    # When I save pruned builds in the "<%= project.name %>" project into the :pruned2 clipboard
    # the output from prune after one hour is same as previous prune
    # Then the expression should be true> cb.pruned1.to_set == cb.pruned2.to_set

  # @author akostadi@redhat.com
  # @case_id 481682
  # @note marked destructive because it prunes builds older than 1m and this
  #   could be unexpected by other scenarios that check older builds
  @admin
  @destructive
  Scenario: Prune old builds by admin command
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
    Then the step should succeed
    When I run the :new_app client command with:
      | template | ruby-helloworld-sample|
    Then the step should succeed

    #Generate enough builds for the oadm command to clean
    Given the "ruby-sample-build-1" build was created
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-sample-build |
    Then the step should succeed

    When I run the :oadm_prune_builds client command with:
      | help ||
    Then the step should succeed
    And the output should contain "completed and failed builds"
    #Wait for the builds to finish:
    Given the "ruby-sample-build-1" build finished
    And the "ruby-sample-build-2" build finished
    And the "ruby-sample-build-3" build finished
    And the "ruby-sample-build-4" build finished
    And the "ruby-sample-build-5" build finished
    And the "ruby-sample-build-6" build finished
    And the "ruby-sample-build-7" build finished
    And the "ruby-sample-build-8" build finished

    ## the real running env is really slow to fninish build, enlarge the time scope for oadm_prune_builds
    When I run the :oadm_prune_builds admin command with:
      | keep_younger_than | 1s    |
      | confirm           | false |
      | keep_complete     | 2     |
      | keep_failed       | 1     |
    Then the step should succeed
    And the output should match:
      | Dry run |
      # make sure we match only builds for current project
      # some builds will succeed, some will fail so can't match exact numbers
      | <%= project.name %>\\s*ruby-sample-build- |
    And I save pruned builds in the "<%= project.name %>" project into the :pruned1 clipboard

    When I run the :oadm_prune_builds admin command with:
      | keep_younger_than | 1s    |
      | confirm           | true  |
      | keep_complete     | 2     |
      | keep_failed       | 1     |
    Then the step should succeed
    And the output should match:
      # make sure we match only builds for current project
      # some builds will succeed, some will fail so can't match exact numbers
      | <%= project.name %>\\s*ruby-sample-build- |

    When I save pruned builds in the "<%= project.name %>" project into the :pruned2 clipboard
    Then the expression should be true> cb.pruned1.to_set == cb.pruned2.to_set

    When I save project builds into the :builds clipboard
    # no pruned builds exist anymore
    Then the expression should be true> (cb.builds & cb.pruned1).empty?
    # completed builds are <= 2
    And the expression should be true> cb.builds.select{|b| b.status?(user: user, status: :complete)[:success]}.size <= 2
    # failed builds are <= 1
    And the expression should be true> cb.builds.select{|b| b.status?(user: user, status: [:failed, :error, :cancelled])[:success]}.size <= 1

    When I run the :delete client command with:
      | object_type       | buildconfig       |
      | object_name_or_id | ruby-sample-build |
      | cascade           | false             |
    Then the step should succeed

    When I run the :oadm_prune_builds admin command with:
      | keep_younger_than | 1s    |
      | confirm           | false |
      | keep_complete     | 2     |
      | keep_failed       | 1     |
      | orphans_noopt     |       |
    Then the step should succeed
    And the output should match:
      | Dry run |
      # make sure we match only builds for current project
      # some builds will succeed, some will fail so can't match exact numbers
      | <%= project.name %>\\s*ruby-sample-build- |
    And I save pruned builds in the "<%= project.name %>" project into the :pruned1 clipboard

    When I run the :oadm_prune_builds admin command with:
      | keep_younger_than | 1s    |
      | confirm           | true  |
      | keep_complete     | 2     |
      | keep_failed       | 1     |
      | orphans_noopt     |       |
    Then the step should succeed
    And the output should match:
      # make sure we match only builds for current project
      # some builds will succeed, some will fail so can't match exact numbers
      | <%= project.name %>\\s*ruby-sample-build- |

    When I save pruned builds in the "<%= project.name %>" project into the :pruned2 clipboard
    Then the expression should be true> cb.pruned1.to_set == cb.pruned2.to_set
    And the project should contain no builds

  # @author cryan@redhat.com
  # @case_id 472759
  Scenario: Show friendly messages when invalid options and values for chain-build sub-command
    When I run the :oadm_build_chain client command with:
      | invalid_option | -invalid-opt|
    Then the step should fail
    And the output should contain "unknown shorthand flag"
    When I run the :oadm_build_chain client command with:
      | invalid_option | ---all |
    Then the step should fail
    And the output should contain "bad flag syntax"
    When I run the :oadm_build_chain client command with:
      | invalid_option | -all |
    Then the step should fail
    And the output should contain "unknown shorthand flag"
    When I run the :oadm_build_chain client command with:
      | imagestreamtag | not-existing/image-repo |
    Then the step should fail
    And the output should contain:
      | doesn't have a resource type "not-existing" |
    When I run the :oadm_build_chain client command with:
      | imagestreamtag | ruby:2.2 |
      | all | true |
    Then the step should fail
    And the output should contain "Error"

  # @author xxia@redhat.com
  # @case_id 489297
  @admin
  Scenario: Negative/invalid options test for oadm prune builds
    When I run the :oadm_prune_builds admin command with:
      | confirm           | false  |
      | keep_complete     | -2.1   |
      | keep_failed       | 1      |
      | keep_younger_than | 1m     |
    Then the step should fail
    And the output should match:
      | [Ii]nvalid argument.*-2.1  |

    When I run the :oadm_prune_builds admin command with:
      | confirm           | false  |
      | keep_complete     | letter |
      | keep_failed       | 1      |
      | keep_younger_than | 1m     |
    Then the step should fail
    And the output should match:
      | [Ii]nvalid argument.*letter|

    When I run the :oadm_prune_builds admin command with:
      | confirm           | false  |
      | keep_complete     | 2      |
      | keep_failed       | 1      |
      | keep_younger_than | 1min   |
    Then the step should fail
    And the output should match:
      | [Ii]nvalid argument.*1min  |
