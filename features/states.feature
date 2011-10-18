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
      | start_a | cmd_a  | end_a | start_b    | cmd_b   | end_b         | start_c       | cmd_c  | end_c         | config                        |
      | pending | echo a | ok    | pending    | echo b  | ok            | pending       | echo c | ok            | examples/basic.yaml           |
      | pending | echo a | ok    | pending    | false b | error         | pending       | echo c | pending       | examples/basic.yaml           |
      | pending | echo a | ok    | pending_nm | echo b  | ok_nm         | pending       | echo c | ok            | examples/advanced_states.yaml |
      | pending | echo a | ok    | pending_nm | false b | error_skipped | pending       | echo c | ok_dirty      | examples/advanced_states.yaml |
      | pending | echo a | ok    | pending_nm | false b | error_skipped | pending_clean | echo c | pending_clean | examples/advanced_states.yaml |

