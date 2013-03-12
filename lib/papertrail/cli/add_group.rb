class Papertrail::Cli::AddGroup
  include Papertrail::CliHelpers

  def self.add_command(slop, opts)
    slop.command 'add-group' do
      banner "add-group - Add a group of systems"
      on :h, :help, "Show usage", default: false do
        puts "\n#{self.help}"
        puts "\n    Usage:\n      papertrail add-group -g mygroup -w mygroup-systems*"
        exit 0
      end
      on :c, :configfile=, "Path to config (~/.papertrail.yml)", default: opts[:configfile]
      on :g, :group=, "Name of group to add"
      on :w, :wildcard=, "Wildcard for system match"

      run do |opts, args|
        Papertrail::Cli::AddGroup.new(opts, args).run
      end
    end
  end

  attr_reader :opts, :args, :connection

  def initialize(opts, args)
    @opts = opts
    @args = args
    @connection = Papertrail::Connection.new(load_configfile(@opts[:configfile]))
  end

  def run
    # Bail if group already exists
    if connection.show_group(opts[:group])
      exit 0
    end

    if connection.create_group(opts[:group], opts[:wildcard])
      exit 0
    end

    exit 1
  end

end
