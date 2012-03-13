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
      attr_reader :opts

      def initialize name, opts = {}
        @tasks = Set.new
        @opts = opts
        @name = name
      end

    end

    def initialize opts
      @groups = {}
      @tasks = {}

      @deps = {}
      @group_stack = []
    end

    def task name, cmd, opts = {}
      group = @group_stack.last
#      puts "#{name}: #{group}"
      opts = group.opts.merge(opts) if group
      node = Node.new(name, cmd, opts)
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

    def resolve_deps
      # resolve groups in dependencies first
      @deps.each do |one, others|
        # resolve left
        if task = @tasks[one]
          tasks = [task]
        elsif group = @groups[one]
          tasks = @tasks.values_at(*group.tasks)
        else
          raise "Unknown task or group #{one}"
        end

        # resolve right
        resolved_others = others.each_with_object(Set.new){|other, acc_rs|
          if task = @tasks[other]
            acc_rs << task
          elsif group = @groups[other]
#            puts "tasks: #{group.tasks.to_a}"
            acc_rs.merge(group.tasks)
          else
            raise "Unknown task or group #{other}"
          end
        }
        tasks.each do |task|
#          puts "#{task.name} depends on #{resolved_others.to_a}"
          task.depends(*resolved_others)
        end
      end
    end

    def enqueue worker
#      puts "Tasks: #{@tasks}"
#      puts "Groups: #{@groups}"
#      puts "Deps: #{@deps}"
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

  end
end
