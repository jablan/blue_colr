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
  STATUS_OK = 'ok'
  STATUS_ERROR = 'error'
  STATUS_PENDING = 'pending'
  STATUS_RUNNING = 'running'
  STATUS_PREPARING = 'preparing'
  STATUS_SKIPPED = 'skipped'

  class << self
    attr_accessor :log, :db, :environment, :db_uri

    # default options to use when launching a process - every field maps to a
    # column in process_items table
    def default_options
      @default_options ||= OpenStruct.new
    end

    # local hash used to store misc runtime options
    def options
      @options ||= OpenStruct.new
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
      @log ||= Logger.new('process_daemon')

      unless @db # not connected
        unless @db_uri # get the config from command line
          @args = parse_command_line ARGV

          raise "No configuration file defined (-c <config>)." if @args["config"].nil?
          raise "Couldn't read #{@args["config"]} file." unless @args['config'] && @conf = YAML::load(File.new(@args["config"]).read)

          @db_uri = @conf['db_url']
          # setting default options that should be written along with all the records to process_items
          if @conf['default_options']
            @conf['default_options'].each do |k,v|
              default_options.send("#{k}=", v)
            end
          end
        end
        @db = Sequel.connect(@db_uri, :logger => @log)
      end
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

    def parse_command_line(args)
      data = Hash.new()

      OptionParser.new do |opts|
        opts.banner = "Usage: process_daemon.rb [options]"

        opts.on("-c CONFIG", "--conf CONFIG", "YAML config file") do |config|
          data["config"] = config
        end

        # process custom args, if given
        @custom_args_block.call(opts) if @custom_args_block

        opts.on_tail('-h', '--help', 'display this help and exit') do
          puts opts
          exit
#          return nil
        end

#        begin
          opts.parse(args)
#        rescue OptionParser::InvalidOption
#          # do nothing
#        end

      end

      return data
    end
  end

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
    def_opts = self.class.default_options.send(:table) # convert from OpenStruct to Hash
    # rejecting fields that do not have corresponding column in the table:
    fields = def_opts.merge(opts).select{|k,_| db[:process_items].columns.member? k}
    id = db[:process_items].insert(fields.merge(:status => STATUS_PREPARING, :cmd => cmd, :queued_at => Time.now))
    waitfor.each do |wid|
      db[:process_item_dependencies].insert(:process_item_id => id, :depends_on_id => wid)
    end
    db[:process_items].filter(:id => id).update(:status => STATUS_PENDING)
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
      failed = db[:process_items].filter(:id => @all_ids, :status => STATUS_ERROR).first
      return failed[:exit_code] if failed
      not_ok_count = db[:process_items].filter(:id => @all_ids).exclude(:status => STATUS_OK).count
      return 0 if not_ok_count == 0 # all ok, finish
      sleep 10
    end
  end
end
