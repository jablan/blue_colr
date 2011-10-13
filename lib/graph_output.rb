# this module, when included in BlueColr, generates GraphViz graph of the invoked processes,
# instead actually enqueueing them.
module GraphOutput

  def self.included target
    target.instance_eval do
      # graph nodes are given unique ids
      def next_id
        @id ||= 0
        @id += 1
      end

      # gets different color for different environments,
      # currently cycling between couple predefined colors
      # TODO: enable submitting color through option
      def get_color group
        colors = [
          '#FFFFFF',
          '#EEFFEE',
          '#EEEEFF',
          '#FFEEEE'
        ]
        @groups ||= []
        @groups << group unless @groups.member? group
        colors[@groups.index(group) % colors.length]
      end

      # override class method launch, we are creating output file here,
      # and we don't need database
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

  # original enqueue enqueues the process to the database,
  # here we should just output a graph elements to the output file
  def graph_enqueue cmd, waitfor = [], opts = {}
    gv_file = self.class.default_options.gv_file
    id = self.class.next_id
    waitfor.each do |wid|
      # output graph edges
      gv_file.puts "  b#{wid} -> b#{id};"
    end
    # determine node label
    label = opts[:label] || cmd
    label.gsub!(/([^\\])"/, '\1""')
    # determine node color
    color = self.class.get_color(opts[:group] || opts[:environment])
    # output node description
    gv_file.puts "  b#{id} [shape=box,style=filled,fillcolor=\"#{color}\",label=\"#{label}\"];"
    # remember id
    @all_ids << id
    id
  end
end
