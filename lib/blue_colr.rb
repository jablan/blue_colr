require 'rubygems'
#require 'date'
require 'logger'
require 'ostruct'
require 'optparse'
require 'yaml'
require 'sequel'
require 'json'

# This class provides a DSL for enqueuing processes, at the same time describing their mutual dependance.
class BlueColr

  # If no alternative statemap is provided, all newly launched processes will have this state by default.
  DEFAULT_PENDING_STATE = 'pending'
  # Used internally.
  PREPARING_STATE = 'preparing'
  # Default state transitions with simple state setup ('PENDING => RUNNING => OK or ERROR')
  DEFAULT_STATEMAP = {
    'on_pending' => {
      DEFAULT_PENDING_STATE => [
        ['running', ['ok', 'skipped']]
      ]
    },
    'on_running' => {
      'running' => {
        'error' => 'error',
        'ok' => 'ok'
      }
    },
    'on_restart' => {
      'error' => 'pending',
      'ok' => 'pending'
    }
  }

  class << self
    attr_accessor :environment
    attr_writer :statemap, :log, :db, :db_uri, :conf

    def log
      @log ||= Logger.new('process_daemon')
    end

    # Configuration hash read from yaml config file
    def conf
      unless @conf
        if @db_url || @db # skip loading config if db set explicitly
          @conf = {}
        else
          parse_command_line unless @args

          raise "No configuration file defined (-c <config>)." if @args["config"].nil?
          raise "Couldn't read #{@args["config"]} file." unless @args['config'] && @conf = YAML::load(File.new(@args["config"]).read)
          # setting default options that should be written along with all the records to process_items
          if @conf['default_options']
            @conf['default_options'].each do |k,v|
              default_options.send("#{k}=", v)
            end
          end

          if @args['params']
            @args['params'].each do |k, v|
              default_options.send("#{k}=", v)
            end
          end
        end
      end
      @conf
    end

    # Sequel DB URI connection string
    def db_uri
      unless @db_uri # get the config from command line
        @db_uri = self.conf['db_url']
      end
      @db_uri
    end

    # Sequel DB connection instance
    def db
      unless @db # not connected
        @db = Sequel.connect(self.db_uri, :logger => self.log)
      end
      @db
    end

    # Default options to use when launching a process - every field maps to a
    # column in process_items table
    def default_options
      @default_options ||= OpenStruct.new
    end

    # Local hash used to store misc runtime options
    def options
      @options ||= OpenStruct.new
    end

    # Map of states that processes pass through (Pending -> Running -> Ok / Error)
    def statemap
      @statemap ||= conf['statemap'] || DEFAULT_STATEMAP
    end

#    # Create new sequential block (see instance method with the same name)
#    def sequential &block
#      self.new.sequential &block
#    end

#    # Create new parallel block (see instance method with the same name)
#    def parallel &block
#      self.new.parallel &block
#    end

    # Usually the root method for launcing a set of tasks.
    def launch opts = {}, &block
      worker = BlueColr.new(:sequential, [], opts)
      db.transaction do
        worker.instance_eval &block
      end
      worker
    end

    # Run a set of tasks (launch it and wait until the last one finishes). exit with returned exitcode.
    def run &block
      worker = launch &block
      exit worker.wait
    end

    # Parse command line arguments. You should call it explicitly if you need to submit some
    # additional custom parameters. Otherwise it will be called automatically in order to get
    # parameters needed for running, such as database connection string.
    def parse_command_line &block
      data = {}

      OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename($0)} [options]"

        opts.on("-c CONFIG", "--conf CONFIG", "YAML config file") do |config|
          data["config"] = config
        end

        opts.on("-p PARAMS", "--params PARAMS", "Additional default options - key: value as JSON string, override values from config file") do |params|
          data["params"] = JSON.parse(params)
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
    
    # Get the next state from pending, given current state and state of all "parent" processes
    def state_from_pending current_state, parent_states
      new_state, _ = self.statemap['on_pending'][current_state].find { |_, required_parent_states|
        (parent_states - required_parent_states).empty?
      }
      new_state
    end

    # Get the next state from running, given current state and whether the command has finished successfully
    def state_from_running current_state, ok
      self.statemap['on_running'][current_state][ok ? 'ok' : 'error']
    end

    # Get the next state to get upon restart, given the current state
    def state_on_restart current_state
      self.statemap['on_restart'][current_state]
    end

    # Get all possible pending states
    def get_pending_states
      self.statemap['on_pending'].map{|state, _| state}
    end

    # Get all possible error states
    def get_error_states
      self.statemap['on_running'].map{|_, new_states| new_states['error']}
    end

    # Get all possible ok states
    def get_ok_states
      self.statemap['on_running'].map{|_, new_states| new_states['ok']}
    end

  end # class methods

  # Use to access the list of ids of all processes that were enqueued
  attr_reader :all_ids
  attr_reader :result


  # All processes enqueued within the given block should be executed sequentially,
  # i.e. one after another.
  def sequential opts = {}, &block
    exec :sequential, opts, &block
  end

  # All processes enqueued within the given block should be executed in parallel
  # (not waiting for each other to finish).
  def parallel opts = {}, &block
    exec :parallel, opts, &block
  end

  def enqueue cmd, waitfor = [], opts = {}
    id = nil
    opts = {status: DEFAULT_PENDING_STATE}.merge(@opts).merge(opts)
    def_opts = self.class.default_options.send(:table) # convert from OpenStruct to Hash
    # rejecting fields that do not have corresponding column in the table:
    fields = def_opts.merge(opts).select{|k,_| db[:process_items].columns.member? k}
    id = db[:process_items].insert(fields.merge(:status => PREPARING_STATE, :cmd => cmd, :queued_at => Time.now))
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

  # Enqueues a single command +cmd+.
  #
  # == Parameters
  # cmd::
  #   A string containing the command that should be executed.
  # options::
  #   A set of optional parameters which override default fields associated with the given command
  #   (e.g. here you can specify different +:environment+ that the command should be launched in,
  #   optional +:description+, or whatever you decide to store along the command).
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

  # Waits for all enqueued processes to finish. The default behaviour for BlueColr is to enqueue commands
  # and exit. If for any reason you need to wait for the commands to finish execution, you can call this method
  # which will wait until all enqueued processes are finished (either with Ok or error state).
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

  private

  def initialize type = :sequential, waitfor = [], opts = {}
    @type = type
    @waitfor = waitfor
    @result = []
    @all_ids = [] # list of all ids of processes enqueued, used if waiting
    @opts = opts
  end

  def db
    self.class.db
  end

  def log
    self.class.log
  end

  def exec type = :sequential, opts = {}, &block
    g = self.class.new type, @waitfor, opts
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
end
