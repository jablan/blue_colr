# this module, when included in BlueColr, generates GraphViz graph of the invoked processes,
# instead actually enqueueing them.
module GraphOutput

  def self.included target
    target.instance_eval do
      def next_id
        @id ||= 0
        @id += 1
      end

      def get_color environment
        colors = [
          '#FFFFFF',
          '#EEFFEE',
          '#EEEEFF',
          '#FFEEEE'
        ]
        @environments ||= []
        @environments << environment unless @environments.member? environment
        colors[@environments.index(environment) % colors.length]
      end

      # override class method launch
      def launch &block
        default_options.gv_filename ||= "output.dot"
        worker = self.new
        File.open(default_options.gv_filename, 'w') do |f|
          default_options.gv_file = f
          f.puts "digraph G {"
          worker.instance_eval &block
          f.puts "}"
        end
        worker
      end

      # override default enqueue method, as just including won't do
      define_method :enqueue, instance_method(:graph_enqueue)
    end
  end

  def graph_enqueue cmd, waitfor = [], opts = {}
    gv_file = self.class.default_options.gv_file
    id = self.class.next_id
    waitfor.each do |wid|
      gv_file.puts "  b#{wid} -> b#{id};"
    end
    label = opts[:label] || cmd
    label.gsub!(/([^\\])"/, '\1""')
    color = self.class.get_color(opts[:environment])
    gv_file.puts "  b#{id} [shape=box,style=filled,fillcolor=\"#{color}\",label=\"#{label}\"];"
    # remember id
    @all_ids << id
    id
  end
end
