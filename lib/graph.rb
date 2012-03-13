require 'set'

class BlueColr

  class Graph
    class Node
      attr_accessor :id
      attr_reader :deps, :opts

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

      def initialize name, opts = {}
        @tasks = Set.new
        @opts = opts
        @name = name
      end

    end

    def initialize opts
      @groups = {}
      @nodes = {}

      @deps = {}
      @group_stack = []
    end

    def task name, cmd, opts = {}
      node = Node.new(name, cmd, opts)
      group = @group_stack.last
      if group
        opts = group.opts.merge(opts)
        group.tasks << node
      end
      @nodes[name] = node
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
    end

    def resolve_deps
      # resolve groups in dependencies first
      @deps.each do |one, others|
        # resolve left
        if task = @nodes[one]
          tasks = [task]
        elsif group = @groups[one]
          tasks = @tasks.values_at(*group.tasks)
        else
          raise "Unknown task or group #{one}"
        end

        # resolve right
        resolved_others = others.each_with_object(Set.new){|other, acc_rs|
          if task = @nodes[other]
            acc_rs << task
          elsif group = @groups[other]
            acc_rs += @tasks.values_at(*group.tasks)
          else
            raise "Unknown task or group #{other}"
          end
        }
        tasks.each do |task|
          task.depends(*resolved_others)
        end
      end
    end

    def enqueue worker
      deps = resolve_deps

      BlueColr.log.info 'Graph#enqueue'
      while !@nodes.values.all?(&:queued?)
        to_enqueue = @nodes.values.find{|node|
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
