require 'papertrail/colorizer'
require 'papertrail/log_regexp'
class Papertrail::Cli::Log
  include Papertrail::CliHelpers

  attr_reader :options, :args, :config, :query_options, :connection

  def initialize(options, args)
    @options = options
    @args = args
    @query_options = {}
    @config = load_configfile @options[:configfile]
    @connection = Papertrail::Connection.new(@config)
    if colorize?
      config_colors!
    end
  end

  def run
    load_query_options!
    if options[:follow]
      tail_query
    elsif options[:min_time]
      time_range_query
    else
      standard_query
    end
  end


  private

  def colorize?
    options[:colorize]
  end

  def config_colors!
    default_regex = Papertrail::LogRegexp[:syslog]
    if options['color-group'] && config[:colorizer][options['color-group']]
      cgroup = config[:colorizer][options['color-group']]
      regex = Papertrail::LogRegexp[cgroup[:type]]
      colors = cgroup[:colors]
    end
    regex = regex || default_regex
    @colorizer = Papertrail::Colorizer.new(regex, colors)
  end

  def standard_query
    search_query = connection.query(query_string, query_options)
    display_results(search_query.search)
  end

  def tail_query
    search_query = connection.query(query_string, query_options)
    loop do
      display_results(search_query.search)
      sleep options[:delay]
    end
  end

  def time_range_query
    min_time = parse_time(options[:min_time])

    if options[:max_time]
      max_time = parse_time(options[:max_time])
    end

    search_results = connection.query(query_string, query_options.merge(:min_time => min_time.to_i, :tail => false)).search

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
      search_results = connection.query(query_string, query_options.merge(:min_id => search_results.max_id, :tail => false)).search
    end
  end

  def query_string
    @query_string ||= args.join(' ')
  end

  def load_query_options!
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
  end

  def display_results(results)
    if options[:json]
      $stdout.puts results.data.to_json
    else
      results.events.each do |event|
        evstr = colorize? ? @colorizer.colorize_message(event.to_s) : event.to_s
        $stdout.puts evstr
      end
    end

    $stdout.flush
  end

end
