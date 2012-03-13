require 'blue_colr'

BlueColr.graph do
  task :foo, 'echo foo'
  task :bar, 'echo bar'
  task :baz, 'echo baz'

  depends :bar => :foo
  depends :baz => [:foo, :bar]
end
