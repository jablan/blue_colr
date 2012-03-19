require 'blue_colr'
require 'blue_colr/graph'

BlueColr::Graph.launch do
  group :g1 do
    task :foo, 'echo foo'
    task :bar, 'echo bar'
  end
  task :baz, 'echo baz'

  depends :bar => :foo
  depends :baz => :g1
end
