require 'blue_colr'

BlueColr.tasks do
  group :g1 do
    task :foo, 'echo foo'
    task :bar, 'echo bar'
  end
  task :baz, 'echo baz'

  depends :bar => :foo
  depends :baz => :g1
end
