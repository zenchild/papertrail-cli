module Papertrail
  # A collection of common syslog regular expressions.
  module LogRegexp

    SYSLOG = /^
      (?<datetime>[A-Z][a-z]+\s+[0-9]{1,2}\s+[0-9]{2}:[0-9]{2}:[0-9]{2})
      \s+
      (?<source>[^\s]+)
      \s+
      (?<process>[^:]+:)
      \s+
      (?<message>.*)
      $/x

    HEROKU = /^
      (?<datetime>[A-Z][a-z]+\s+[0-9]{1,2}\s+[0-9]{2}:[0-9]{2}:[0-9]{2})
      \s+
      (?<source>[^\s]+)
      \s+
      (?<dyno>[^:]+:)
      \s+
      (?<message>.*)
      $/x

    REGEX_MAP = {
      syslog: SYSLOG,
      heroku: HEROKU,
    }

    def self.[](attr)
      REGEX_MAP[attr]
    end
  end
end
