require 'blue_colr'
require 'date'

def test
  'foo'
end

BlueColr.default_options.environment = 'test'
BlueColr.default_options.process_from = Date.today

BlueColr.launch do
  # by default, execute commands sequentially
  run 'sleep 1; echo 1'
  parallel do # perform commands in block in parallel
    sequential do
      # you can call your methods when constructing command string:
      run "sleep 4; echo #{test}"
      # simulate error by returning exit code other than 0:
      run 'sleep 4; exit 1'
      # call non-existing command:
      run 'sleep 3; asdasdd'
      # use conditions to launch process only in certain cases
      if Date.today.wday == 1 # if monday
        run 'echo 4.5'
      end
    end
    run 'sleep 2; echo 5'
  end
  run 'sleep 1; echo 6'
end
