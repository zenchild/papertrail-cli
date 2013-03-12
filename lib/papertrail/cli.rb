require 'slop'
require 'yaml'
require 'chronic'

require 'papertrail'
require 'papertrail/connection'
require 'papertrail/cli_helpers'

module Papertrail
  class Cli
    include Papertrail::CliHelpers

    attr_reader :options, :query_options, :connection

    USAGE = <<-EOF
Examples:
    papertrail -f
    papertrail something
    papertrail 1.2.3 Failure
    papertrail -s ns1 "connection refused"
    papertrail -f "(www OR db) (nginx OR pgsql) -accepted"
    papertrail -f -g Production "(nginx OR pgsql) -accepted"
    papertrail -g Production --min-time 'yesterday at noon' --max-time 'today at 4am'
More: https://papertrailapp.com/
    EOF
    LIST_SYSTEMS_USAGE = "List systems defined in Papertrail."
    LIST_GROUPS_USAGE = "List groups defined in Papertrail."

    def initialize
      # Let it slide if we have invalid JSON
      if JSON.respond_to?(:default_options)
        JSON.default_options[:check_utf8] = false
      end
      @slop = parse_opts!
    end


    private

    def get_default_configfile
      paths = %w{.papertrail.yml ~/.papertrail.yml}.collect{|f| File.expand_path(f)}
      default_path = paths[-1]
      paths.each do |p|
        return p if File.exists?(p)
      end
      default_path
    end

    def parse_opts!
      config_file = get_default_configfile
      Slop.parse do |op|
        op.banner "papertrail - command-line tail and search for Papertrail log management service"

        op.on :h, :help, "Show usage", default: false do
          puts "\n#{op.help}\n\n#{USAGE}"
          exit 0
        end
        op.on :version, "Show papertrail-cli version" do
          puts "version: #{Papertrail::VERSION}"
          exit 0
        end
        op.on :c, :configfile=, "Path to config (~/.papertrail.yml)", default: config_file

        Cli::Lister.define_command('list-systems', op, banner: LIST_SYSTEMS_USAGE, configfile: config_file)
        Cli::Lister.define_command('list-groups', op, banner: LIST_GROUPS_USAGE, configfile: config_file)
        Cli::AddGroup.add_command(op, configfile: config_file)

        op.on :f, :follow, "Continue running and print new events (off)", default: false
        op.on :d, :delay=, "Delay in seconds between refresh (2)", as: :integer, default: 2
        op.on :j, :json, "Output raw json data", default: false
        op.on :s, :system=, "System to search"
        op.on :g, :group=, "Group to search"
        op.on 'min-time=', "Earliest time to search from" do |o|
          op.fetch_option('min-time').value = Chronic.parse(o)
        end
        op.on 'max-time=', "Latest time to search from" do |o|
          op.fetch_option('max-time').value = Chronic.parse(o)
        end

        op.run do |opts, args|
          Papertrail::Cli::Log.new(opts, args).run
        end
      end
    end

  end
end

require 'papertrail/cli/lister'
require 'papertrail/cli/add_group'
require 'papertrail/cli/log'
