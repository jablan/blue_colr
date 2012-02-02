Feature: bcrun
  Tool to enqueue tasks from command line

  Scenario: Passing environment through a command line argument
    When I start bcrun with argument -p '{"environment": "foo"}'
    Then I should see one task in environment "foo"
