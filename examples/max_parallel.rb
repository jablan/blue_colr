require 'blue_colr'

BlueColr.default_options.environment = 'test'

BlueColr.launch do
  # by default, execute commands sequentially
  parallel do # perform commands in block in parallel
    run 'sleep 2; echo foo'
    run 'sleep 2; echo foo'
    run 'sleep 2; echo foo'
    run 'sleep 2; echo foo'
    run 'sleep 2; echo foo'
    run 'sleep 2; echo foo'
    run 'sleep 2; echo foo'
    run 'sleep 2; echo foo'
    run 'sleep 2; echo foo'
  end
end
