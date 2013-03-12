module Papertrail
  class Colorizer
    attr_reader :regex, :colors

    DEFAULT_COLORS = [31, 32, 33, 34, 35, 36, 37]

    def initialize(regex, colors = nil)
      @regex  = regex
      @colors = colors || {}
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
