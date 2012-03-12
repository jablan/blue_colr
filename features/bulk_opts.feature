Feature: bulk_opts
  Options given to a group of tasks should apply to all of them

  Scenario: Passing description through a group
    When I start sequence of 3 tasks with field "description" with value "foo"
    Then all 3 tasks should have field "description" with value "foo"
