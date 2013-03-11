require 'slop'
require 'yaml'
require 'chronic'

require 'papertrail/connection'
require 'papertrail/cli_helpers'

module Papertrail
  class Cli
    include Papertrail::CliHelpers

    attr_reader :options, :query_options, :connection

    def initialize
      # Let it slide if we have invalid JSON
      if JSON.respond_to?(:default_options)
        JSON.default_options[:check_utf8] = false
      end
      @slop = parse_log_opts!
      @options = load_configfile(@slop[:configfile]).merge(@slop.to_hash)
      @connection = Papertrail::Connection.new(@options)
      @query_options = {}
    end

    def run
      if options[:system]
        query_options[:system_id] = connection.find_id_for_source(options[:system])
        unless query_options[:system_id]
          abort "System \"#{options[:system]}\" not found"
        end
      end

      if options[:group]
        query_options[:group_id] = connection.find_id_for_group(options[:group])
        unless query_options[:group_id]
          abort "Group \"#{options[:group]}\" not found"
        end
      end

      if options[:follow]
        search_query = connection.query(ARGV[0], query_options)

        loop do
          display_results(search_query.search)
          sleep options[:delay]
        end
      elsif options[:min_time]
        query_time_range
      else
        set_min_max_time!(options, query_options)
        search_query = connection.query(ARGV[0], query_options)
        display_results(search_query.search)
      end
    end

    def query_time_range
      min_time = parse_time(options[:min_time])

      if options[:max_time]
        max_time = parse_time(options[:max_time])
      end

      search_results = connection.query(ARGV[0], query_options.merge(:min_time => min_time.to_i, :tail => false)).search

      loop do
        search_results.events.each do |event|
          # If we've found an event beyond what we were looking for, we're done
          if max_time && event.received_at > max_time
            break
          end

          if options[:json]
            $stdout.puts event.data.to_json
          else
            $stdout.puts event
          end
        end

        # If we've found the end of what we're looking for, we're done
        if max_time && search_results.max_time_at > max_time
          break
        end

        if search_results.reached_end?
          break
        end

        # Perform the next search
        search_results = connection.query(ARGV[0], query_options.merge(:min_id => search_results.max_id, :tail => false)).search
      end
    end

    def display_results(results)
      if options[:json]
        $stdout.puts results.data.to_json
      else
        results.events.each do |event|
          $stdout.puts event
        end
      end

      $stdout.flush
    end


    private


    def usage
      <<-EOF
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
    end

    def get_default_configfile
      paths = %w{.papertrail.yml ~/.papertrail.yml}.collect{|f| File.expand_path(f)}
      default_path = paths[-1]
      paths.each do |p|
        return p if File.exists?(p)
      end
      default_path
    end

    def parse_log_opts!
      config_file = get_default_configfile
      usage_str   = usage
      Slop.parse do
        banner "papertrail - command-line tail and search for Papertrail log management service"

        on :h, :help, "Show usage", default: false do
          puts "\n#{self.help}\n\n#{usage_str}"
          exit 0
        end
        on :f, :follow, "Continue running and print new events (off)", default: false
        on :d, :delay=, "Delay in seconds between refresh (2)", as: :integer, default: 2
        on :c, :configfile=, "Path to config (~/.papertrail.yml)", default: config_file
        on :j, :json, "Output raw json data", default: false
        on :s, :system=, "System to search"
        on :g, :group=, "Group to search"
        on 'min-time=', "Earliest time to search from" do |o|
          fetch_option('min-time').value = Chronic.parse(o)
        end
        on 'max-time=', "Latest time to search from" do |o|
          fetch_option('max-time').value = Chronic.parse(o)
        end
      end
    end

  end
end
