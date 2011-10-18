Feature: Parallel execution
  Whether tasks really execute in parallel

  Scenario: All done in parallel
    Given I created 10 parallel tasks of 1 second each
    When I run daemon for 10 secs using "examples/basic.yaml"
    Then all tasks should be executed within 0 to 2 seconds

  Scenario: Max 3 in parallel
    Given I created 10 parallel tasks of 1 second each
    When I run daemon for 50 secs using "examples/basic.yaml" with max 3 parallel tasks
    Then all tasks should be executed within 3 to 5 seconds

