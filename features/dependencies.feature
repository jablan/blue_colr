Feature: Dependencies
  Allow for explicit dependency specifying

  Scenario: Three tasks and dependency between them
    Given I have task "foo" which does "echo foo"
    And I have task "bar" which does "echo bar"
    And I have task "baz" which does "echo baz"
    And "bar" depends on "foo"
    And "baz" depends on "bar"
    When I enqueue
    Then there will be 3 process_items
    And process which does "echo foo" will have 0 dependencies
    And process which does "echo bar" will have 1 dependencies
    And process which does "echo bar" will depend on one which does "echo foo"
    And process which does "echo baz" will have 1 dependencies
    And process which does "echo baz" will depend on one which does "echo bar"

  Scenario: Task depends on a group
    Given I have task "foo" in group "g" which does "echo foo"
    And I have task "bar" in group "g" which does "echo bar"
    And I have task "baz" which does "echo baz"
    And "baz" depends on "g"
    When I enqueue
    Then there will be 3 process_items
    And process which does "echo foo" will have 0 dependencies
    And process which does "echo bar" will have 0 dependencies
    And process which does "echo baz" will have 2 dependencies
    And process which does "echo baz" will depend on one which does "echo foo"
    And process which does "echo baz" will depend on one which does "echo bar"

  Scenario: Group depends on a task
    Given I have task "foo" in group "g" which does "echo foo"
    And I have task "bar" in group "g" which does "echo bar"
    And I have task "baz" which does "echo baz"
    And "g" depends on "baz"
    When I enqueue
    Then there will be 3 process_items
    And process which does "echo foo" will have 1 dependencies
    And process which does "echo foo" will depend on one which does "echo baz"
    And process which does "echo bar" will have 1 dependencies
    And process which does "echo bar" will depend on one which does "echo baz"
    And process which does "echo baz" will have 0 dependencies
