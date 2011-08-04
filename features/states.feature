Feature: Basic states
  Basic states should be handled appropriately by the daemon

  Scenario Outline: Different starting ending states
    Given I created task "a" with status "<start_a>" which executes "<cmd_a>"
    And I created task "b" with status "<start_b>" which executes "<cmd_b>" and depends on task "a"
    And I created task "c" with status "<start_c>" which executes "<cmd_c>" and depends on task "b"
    When I run daemon for 15 secs using "<config>"
    Then task "a" should have status "<end_a>"
    And task "b" should have status "<end_b>"
    And task "c" should have status "<end_c>"

    Examples:
      | start_a | cmd_a | end_a | start_b | cmd_b | end_b | start_c | cmd_c | end_c | config |
      | PENDING | echo a | OK | PENDING | echo b | OK | PENDING | echo c | OK | examples/basic.yaml |
      | PENDING | echo a | OK | PENDING | false b | ERROR | PENDING | echo c | PENDING | examples/basic.yaml |
      | PENDING | echo a | OK | PENDING_NM | echo b | OK_NM | PENDING | echo c | OK | examples/advanced_states.yaml |
      | PENDING | echo a | OK | PENDING_NM | false b | ERROR_SKIPPED | PENDING | echo c | OK_DIRTY | examples/advanced_states.yaml |
      | PENDING | echo a | OK | PENDING_NM | false b | ERROR_SKIPPED | PENDING_CLEAN | echo c | PENDING_CLEAN | examples/advanced_states.yaml |

