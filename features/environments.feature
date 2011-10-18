Feature: Different environments
  Whether environments don't mix

  Scenario: Two tasks, different environment
    Given I created a successful task "a" in environment "foo"
    And I created a successful task "b" in environment "bar"
    When I run daemon for 10 secs using "examples/basic.yaml" in environment "foo"
    Then task "a" should have status "ok"
    And task "b" should have status "pending"
