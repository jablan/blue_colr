require 'sequel'
require 'blue_colr'
require 'rspec'

Before do
  db_uri = 'postgres://test:test@localhost/test'
  BlueColr.db_uri = db_uri
  DB = Sequel.connect(db_uri)
  DB[:process_item_dependencies].delete
  DB[:process_items].delete
  @bc = BlueColr.new
  @task_names = {}
end

After do
end

Given /^I created task "([^"]*)" with status "([^"]*)" which executes "([^"]*)"$/ do |name, status, cmd|
  id = @bc.enqueue(cmd, [], :status => status)
  @task_names[name] = id
end

Given /^I created task "([^"]*)" with status "([^"]*)" which executes "([^"]*)" and depends on task "([^"]*)"$/ do |name, status, cmd, prev|
  id = @bc.enqueue(cmd, [@task_names[prev]], :status => status)
  @task_names[name] = id
end

When /^I run daemon for (\d+) secs using "([^"]*)"$/ do |time, conf|
  @pid = Process.spawn("./bin/bluecolrd -c #{conf}", :out=>"/dev/null")
  Kernel.sleep time.to_i
  Process.kill('SIGTERM', @pid)
end

Then /^task "([^"]*)" should have status "([^"]*)"$/ do |name, status|
  DB[:process_items].filter(:id => @task_names[name]).first[:status].should == status
end

