# This class provides a simple DSL for enqueuing processes to the database
# in particular order.

require 'rubygems'
require 'date'
require 'logger'
require 'ostruct'
require 'optparse'
require 'yaml'
require 'sequel'


class BlueColr
#  STATUS_OK = 'ok'
#  STATUS_ERROR = 'error'
#  STATUS_PENDING = 'pending'
#  STATUS_RUNNING = 'running'
#  STATUS_PREPARING = 'preparing'
#  STATUS_SKIPPED = 'skipped'

  # default state transitions with simple state setup ('PENDING => RUNNING => OK or ERROR')
  DEFAULT_STATEMAP = {
    'on_pending' => {
      'PENDING' => [
        ['RUNNING', ['OK', 'SKIPPED']]
      ]
    },
    'on_running' => {
      'RUNNING' => {
        'error' => 'ERROR',
        'ok' => 'OK'
      }
    },
    'on_restart' => {
      'ERROR' => 'PENDING',
      'OK' => 'PENDING'
    }
  }

  class << self
    attr_accessor :environment
    attr_writer :statemap, :log, :db, :db_uri, :conf

    def log
      @log ||= Logger.new('process_daemon')
    end

    def conf
      unless @conf
        parse_command_line unless @args

        raise "No configuration file defined (-c <config>)." if @args["config"].nil?
        raise "Couldn't read #{@args["config"]} file." unless @args['config'] && @conf = YAML::load(File.new(@args["config"]).read)

        # setting default options that should be written along with all the records to process_items
        if @conf['default_options']
          @conf['default_options'].each do |k,v|
            default_options.send("#{k}=", v)
          end
        end
      end
      @conf
    end

    def db_uri
      unless @db_uri # get the config from command line
        @db_uri = self.conf['db_url']
      end
      @db_uri
    end
    
    def db
      unless @db # not connected
        @db = Sequel.connect(self.db_uri, :logger => self.log)
      end
      @db
    end

    # default options to use when launching a process - every field maps to a
    # column in process_items table
    def default_options
      @default_options ||= OpenStruct.new
    end

    # local hash used to store misc runtime options
    def options
      @options ||= OpenStruct.new
    end

    def statemap
      @statemap ||= conf['statemap'] || DEFAULT_STATEMAP
    end

    def sequential &block
      self.new.sequential &block
    end

    def parallel &block
      self.new.parallel &block
    end

    # set custom commandline parameters from parent script, will be called upon
    # command line parameter extraction
    def custom_args &block
      @custom_args_block = block
    end

    # launch a set of tasks, provided within a given block
    def launch &block

      worker = self.new
      db.transaction do
        worker.instance_eval &block
      end
      worker
    end

    # run a set of tasks (launch it and wait until the last one finishes). exit with returned exitcode.
    def run &block
      worker = launch &block
      exit worker.wait
    end

    def parse_command_line &block
      data = {}

      OptionParser.new do |opts|
        opts.banner = "Usage: process_daemon.rb [options]"

        opts.on("-c CONFIG", "--conf CONFIG", "YAML config file") do |config|
          data["config"] = config
        end

        # process custom args, if given
        block.call(opts) if block_given?

        opts.on_tail('-h', '--help', 'display this help and exit') do
          puts opts
          exit
#          return nil
        end

#        begin
          opts.parse(ARGV)
#        rescue OptionParser::InvalidOption
#          # do nothing
#        end

      end

      @args = data
    end


    # state related methods
    
    # get the next state from pending, given current state and state of all "parent" processes
    def state_from_pending current_state, parent_states
      new_state, _ = self.statemap['on_pending'][current_state].find { |_, required_parent_states|
        (parent_states - required_parent_states).empty?
      }
      new_state
    end

    # get the next state from running, given current state and whether the command has finished successfully
    def state_from_running current_state, ok
      self.statemap['on_running'][current_state][ok ? 'ok' : 'error']
    end

    # get the next state to get upon restart, given the current state
    def state_on_restart current_state
      self.statemap['on_restart'][current_state]
    end

    # get all possible pending states
    def get_pending_states
      self.statemap['on_pending'].map{|state, _| state}
    end

    # get all possible error states
    def get_error_states
      self.statemap['on_running'].map{|_, new_states| new_states['error']}
    end

    # get all possible ok states
    def get_ok_states
      self.statemap['on_running'].map{|_, new_states| new_states['ok']}
    end

  end # class methods

  attr_reader :all_ids, :result

  def initialize type = :sequential, waitfor = []
    @type = type
    @waitfor = waitfor
    @result = []
    @all_ids = [] # list of all ids of processes enqueued, used if waiting
  end

  def db
    self.class.db
  end

  def log
    self.class.log
  end

  def sequential &block
    exec :sequential, &block
  end

  def parallel &block
    exec :parallel, &block
  end

  def exec type = :sequential, &block
    g = self.class.new type, @waitfor
    g.instance_eval &block
    ids = g.result
    if @type == :sequential
      @waitfor = ids
      @result = ids
    else
      @result += ids
    end
    @result
  end

  def enqueue cmd, waitfor = [], opts = {}
    id = nil
    opts = {status: 'PENDING'}.merge(opts)
    def_opts = self.class.default_options.send(:table) # convert from OpenStruct to Hash
    # rejecting fields that do not have corresponding column in the table:
    fields = def_opts.merge(opts).select{|k,_| db[:process_items].columns.member? k}
    id = db[:process_items].insert(fields.merge(:status => 'PREPARING', :cmd => cmd, :queued_at => Time.now))
    waitfor.each do |wid|
      db[:process_item_dependencies].insert(:process_item_id => id, :depends_on_id => wid)
    end
    db[:process_items].filter(:id => id).update(:status => opts[:status])
#    id = TaskGroup.counter
    log.info "enqueueing #{id}: #{cmd}, waiting for #{waitfor.inspect}"
    # remember id
    @all_ids << id
    id
  end

  def run cmd, opts = {}
    id = enqueue cmd, @waitfor, opts
    if @type == :sequential
      @waitfor = [id]
      @result = [id]
    else
      @result << id
    end
    @result
  end

  # wait for all enqueued processes to finish
  def wait
    log.info 'Waiting for all processes to finish'
    loop do
      failed = db[:process_items].filter(:id => @all_ids, :status => BlueColr.get_error_states).first
      return failed[:exit_code] if failed
      not_ok_count = db[:process_items].filter(:id => @all_ids).exclude(:status => BlueColr.get_ok_states).count
      return 0 if not_ok_count == 0 # all ok, finish
      sleep 10
    end
  end
end
