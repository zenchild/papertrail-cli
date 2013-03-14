require 'papertrail/log_regexp'
module Papertrail
  class Colorizer
    attr_reader :regex, :colors

    DEFAULT_COLORS = [31, 32, 33, 34, 35, 36, 37]

    def initialize(config)
      @regex  = LogRegexp[config[:type]]
      @colors = config[:colors] || {}
    end

    def display(results)
      results.events.each do |event|
        $stdout.puts colorize_message(event.to_s)
      end
      $stdout.flush
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

    def colorize_message(log)
      mdata = log.match(regex)
      return log unless mdata
      str = ""
      mdata.names.collect(&:to_sym).each_with_index do |n, idx|
        color = colors[n] || DEFAULT_COLORS[idx % DEFAULT_COLORS.length]
        str += " #{colorize_text(mdata[n], color)}"
      end
      str.strip
    end

    def colorize_text(text, color)
      "\033[#{color}m#{text}\033[0m"
    end
  end
end
