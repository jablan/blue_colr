require 'set'

class BlueColr

  # Provides support for setting explicit dependencies, as opposed using
  # +sequential+ and +parallel+ blocks to set them. Check out
  # +dependencies.rb+ in +examples/+ to see how it works.
  class Graph
    class Node
      # db id got when inserted the task
      attr_accessor :id
      attr_reader :deps, :opts, :name

      def initialize name, cmd, opts = {}
        @opts = opts
        @name = name
        @opts[:cmd] = cmd
        @deps = Set.new
        @groups = []
      end

      def set_opts opts = {}
        @opts.merge!(opts)
      end

      def depends *others
        @deps += others.flatten
      end

      def queued?
        ! @id.nil?
      end

      def cmd
        @opts[:cmd]
      end
    end

    class Group
      attr_accessor :tasks
      attr_reader :opts, :name

      def initialize name, opts = {}
        @tasks = Set.new
        @opts = opts
        @name = name
      end

    end

    # class methods

    def self.launch(opts = {}, &block)
      worker = BlueColr.new(:sequential, [], opts)
      BlueColr.db.transaction do
        graph = BlueColr::Graph.new(opts)
        graph.instance_eval &block
        graph.enqueue(worker)
      end
    end

    # instance methods

    def initialize opts = {}
      @groups = {}
      @tasks = {}
      @opts = opts

      @deps = {}
      @group_stack = []
    end

    def task name, cmd, opts = {}
      group = @group_stack.last
#      puts "#{name}: #{group}"
      task_opts = @opts.dup # start with root options
      task_opts = task_opts.merge(group.opts) if group # merge in group options
      task_opts[:group] = group.name if group
      task_opts = task_opts.merge(opts) # merge in specific task options
      node = Node.new(name, cmd, task_opts)
      group.tasks << node if group
      @tasks[name] = node
    end

    def depends hash
      hash.each do |name, others|
        @deps[name] ||= Set.new
        @deps[name] += [others].flatten
      end
    end

    def group name, opts = {}
      g = Group.new name, opts
      @groups[name] = g
      @group_stack.push(g)
      yield
      @group_stack.pop
    end

    def enqueue worker
      resolve_deps

      BlueColr.log.info 'Graph#enqueue'
      while !@tasks.values.all?(&:queued?)
        to_enqueue = @tasks.values.find{|node|
          # first node which has all dependencies queued already
          !node.queued? && node.deps.all?(&:queued?)
        }
        raise "circular deps?" unless to_enqueue
        depends_on_ids = to_enqueue.deps.map(&:id)
        id = worker.enqueue(to_enqueue.cmd, depends_on_ids, to_enqueue.opts)
        to_enqueue.id = id
      end
    end

    private

    # As the user can specify both groups and tasks both in the left
    # or right side of dependency relation, we have to resolve before
    # queueing to the database (replace groups with belonging tasks)
    def resolve_deps
      # resolve groups in dependencies first
      @deps.each do |one, others|
        # resolve left
        if task = @tasks[one]
          tasks = [task]
        elsif group = @groups[one]
          tasks = group.tasks
        else
          raise "Unknown task or group #{one}"
        end

        # resolve right
        resolved_others = others.each_with_object(Set.new){|other, acc_rs|
          if task = @tasks[other]
            acc_rs << task
          elsif group = @groups[other]
            acc_rs.merge(group.tasks)
          else
            raise "Unknown task or group #{other}"
          end
        }
        tasks.each do |task|
          task.depends(*resolved_others)
        end
      end
    end

  end
end
