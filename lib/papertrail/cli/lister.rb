class Papertrail::Cli::Lister
  include Papertrail::CliHelpers

  def self.define_command(type, slop, opts = {})
    lister_method = type.gsub('-','_').to_sym
    slop.command type do
      banner opts[:banner] if opts[:banner]
      on :h, :help, "Show usage", default: false do
        puts "\n#{self.help}"
        exit 0
      end
      on :c, :configfile=, "Path to config (~/.papertrail.yml)", default: opts[:configfile]
      on :j, :json, "Output raw json data", default: false

      run do |opts, args|
        Papertrail::Cli::Lister.new(lister_method, opts, args).run
      end
    end
  end

  attr_reader :type, :opts, :args, :connection

  def initialize(type, opts, args)
    @type = type
    @opts = opts
    @args = args
    @connection = Papertrail::Connection.new(load_configfile(@opts[:configfile]))
  end

  def run
    display_listing connection.send(type, opts[:json])
    exit 0
  end

end
