require 'sequel'
require 'blue_colr'
require 'rspec'

Before do
  db_uri = 'sqlite://examples/test.db'
#  db_uri = 'postgres://test:test@localhost/test'
  BlueColr.db_uri = db_uri
  DB = Sequel.connect(db_uri)
  DB[:process_item_dependencies].delete
  DB[:process_items].delete
  @bc = BlueColr.new
  @task_names = {}
end

After do
  DB[:process_item_dependencies].delete
  DB[:process_items].delete
end

Transform /^(-?\d+)$/ do |number|
  number.to_i
end

Given /^I created task "([^"]*)" with status "([^"]*)" which executes "([^"]*)"$/ do |name, status, cmd|
  id = @bc.enqueue(cmd, [], :status => status)
  @task_names[name] = id
end

Given /^I created task "([^"]*)" with status "([^"]*)" which executes "([^"]*)" and depends on task "([^"]*)"$/ do |name, status, cmd, prev|
  id = @bc.enqueue(cmd, [@task_names[prev]], :status => status)
  @task_names[name] = id
end

Given /^I created a successful task "([^"]*)" in environment "([^"]*)"$/ do |name, env|
  id = @bc.enqueue("true", [], :environment => env)
  @task_names[name] = id
end

When /^I run daemon for (\d+) secs using "([^"]*)"$/ do |time, conf|
  @pid = Process.spawn("./bin/bluecolrd -c #{conf}", :out=>"/dev/null")
  Kernel.sleep time.to_i
  Process.kill('SIGTERM', @pid)
end

When /^I run daemon for (\d+) secs using "([^"]*)" in environment "([^"]*)"$/ do |time, conf, env|
  @pid = Process.spawn("./bin/bluecolrd -c #{conf} -e #{env}", :out=>"/dev/null")
  Kernel.sleep time.to_i
  Process.kill('SIGTERM', @pid)
end

When /^I run daemon for (\d+) secs using "([^"]*)" with max (\d+) parallel tasks$/ do |time, conf, parallel_count|
  @pid = Process.spawn("./bin/bluecolrd -c #{conf} -m #{parallel_count}", :out=>"/dev/null")
  Kernel.sleep time.to_i
  Process.kill('SIGTERM', @pid)
end

Then /^task "([^"]*)" should have status "([^"]*)"$/ do |name, status|
  DB[:process_items].filter(:id => @task_names[name]).first[:status].should == status
end

# parallel test

Given /^I created (\d+) parallel tasks of (\d+) second each$/ do |taskcount, duration|
  BlueColr.launch do
    parallel do
      taskcount.times do
        run "sleep #{duration}"
      end
    end
  end
end

Then /^all tasks should be executed within (\d+) to (\d+) seconds$/ do |time_min, time_max|
  times = DB[:process_items].inject([]) do |acc, pi|
    st, et = pi[:started_at], pi[:ended_at]
    acc + [[st, :start], [et, :end]]
  end
  times = times.sort_by(&:first)
  total, _, _ = times.inject([0.0, 0, nil]) do |(total, level, last_start), (time, type)|
    if type == :start
      last_start = time if level == 0
      level += 1
    else
      total += time - last_start if level == 1
      level -= 1
    end
    [total, level, last_start]
  end
  puts "Total: #{total}"
  (time_min..time_max).should === total
end

# bcrun

When /^I start bcrun with argument (.*)$/ do |arg|
  Kernel.system("./bin/bcrun -x true -c examples/basic.yaml #{arg}")
end

Then /^I should see one task in environment "([^"]*)"$/ do |env|
  DB[:process_items].filter(:environment => env).count.should > 0
end

