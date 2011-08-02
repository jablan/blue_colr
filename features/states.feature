Feature: Basic states
  Basic states should be handled appropriately by the daemon

  Scenario: Standard states, everything OK
    Given I created task "a" with status "PENDING" which executes "echo a"
    And I created task "b" with status "PENDING" which executes "echo b" and depends on task "a"
    And I created task "c" with status "PENDING" which executes "echo c" and depends on task "b"
    When I run daemon for 15 secs using "examples/basic.yaml"
    Then task "a" should have status "OK"
    And task "b" should have status "OK"
    And task "c" should have status "OK"

  Scenario: Standard states, middle process crashes
    Given I created task "a" with status "PENDING" which executes "echo a"
    And I created task "b" with status "PENDING" which executes "false b" and depends on task "a"
    And I created task "c" with status "PENDING" which executes "echo c" and depends on task "b"
    When I run daemon for 15 secs using "examples/basic.yaml"
    Then task "a" should have status "OK"
    And task "b" should have status "ERROR"
    And task "c" should have status "PENDING"

  Scenario: Advanced states, everything OK
    Given I created task "a" with status "PENDING" which executes "echo a"
    And I created task "b" with status "PENDING_NM" which executes "echo b" and depends on task "a"
    And I created task "c" with status "PENDING" which executes "echo c" and depends on task "b"
    When I run daemon for 15 secs using "examples/advanced_states.yaml"
    Then task "a" should have status "OK"
    And task "b" should have status "OK_NM"
    And task "c" should have status "OK"

  Scenario: Advanced states, middle broke
    Given I created task "a" with status "PENDING" which executes "echo a"
    And I created task "b" with status "PENDING_NM" which executes "false b" and depends on task "a"
    And I created task "c" with status "PENDING" which executes "echo c" and depends on task "b"
    When I run daemon for 15 secs using "examples/advanced_states.yaml"
    Then task "a" should have status "OK"
    And task "b" should have status "ERROR_SKIPPED"
    And task "c" should have status "OK_DIRTY"

  Scenario: Advanced states, middle broke, last clean
    Given I created task "a" with status "PENDING" which executes "echo a"
    And I created task "b" with status "PENDING_NM" which executes "false b" and depends on task "a"
    And I created task "c" with status "PENDING_CLEAN" which executes "echo c" and depends on task "b"
    When I run daemon for 15 secs using "examples/advanced_states.yaml"
    Then task "a" should have status "OK"
    And task "b" should have status "ERROR_SKIPPED"
    And task "c" should have status "PENDING_CLEAN"
