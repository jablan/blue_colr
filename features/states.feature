Feature: Advanced states
  Advanced states should be handled appropriately by the daemon

  Scenario: Standard states, everything OK
    Given I created task "a" with status "PENDING" which executes "echo a"
    And I created task "b" with status "PENDING" which executes "echo b" and depends on task "a"
    And I created task "c" with status "PENDING" which executes "echo c" and depends on task "b"
    When I run daemon for 15 secs
    Then task "a" should have status "OK"
    And task "b" should have status "OK"
    And task "c" should have status "OK"
