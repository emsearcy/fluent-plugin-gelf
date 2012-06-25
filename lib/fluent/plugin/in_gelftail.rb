module Fluent

class GELFTailInput < TailInput

  Plugin.register_input("gelftail", self)    

  # gelfhost parameter:
  #   nil (default)     auto-add our hostname unless "host" is parsed from file
  #   "!"               do not modify/add "host" field
  #   "custom_string"   set hostname to custom_string
  config_param :gelfhost, :string, :default => nil

  def initialize
    super
    require 'socket'
  end

  def configure_parser(conf)
    # Template 'apache' (override of tail's 'apache')
    # short_message is "common log" format
    # full_message is "combined log" format

    TextParser.register_template('gelf-apache', /^(?<full_message>(?<short_message>(?<client>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*))(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")?)$/, "%d/%b/%Y:%H:%M:%S %z")

    # Template 'nginx'
    # short_message is "common log" format
    # full_message is "combined log" format
    #
    # additional fields correspond to this logging format:
    #
    # log_format  jumbo  '$remote_addr - $remote_user [$time_local] "$request" '
    #                    '$status $body_bytes_sent "$http_referer" '
    #                    '"$http_user_agent" "$http_x_forwarded_for" '
    #                    '$msec $scheme "$http_host" time $request_time '
    #                    'recv $request_length sent $bytes_sent ($body_bytes_sent) '
    #                    'from $upstream_addr '
    #                    '$upstream_cache_status "$upstream_http_cache_control" '
    #                    '$upstream_status time $upstream_response_time';

    TextParser.register_template('gelf-nginx', /^(?<full_message>(?<short_message>(?<client>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*))(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")?)(?: "(?<x-forwarded-for>[^\"]*)")?(?: [0-9]+\.(?<msec>[0-9]{3}) (?<schema>[^ ]+) "(?<vhost>[^\"]*)" time (?<request_time>[0-9.]+) recv (?<request_length>[0-9]+) sent (?<bytes_sent>[0-9]+) \((?<body_bytes_sent>[0-9]+)\) from (?<upstream_addr>.+) (?<upstream_cache_status>.+) "(?<upstream_http_cache_control>[^\"]*)" (?<upstream_status>.+) time (?<upstream_response_time>.+))?$/, "%d/%b/%Y:%H:%M:%S %z")

    @parser = TextParser.new
    @parser.configure(conf)
  end

  def parse_line(line)
    time, record = super(line)
    
    if @gelfhost === nil then
      if !record.has_key?('host') then
        record['host'] = Socket.gethostname
      end
    elsif @gelfhost != '!' then
        record['host'] = @gelfhost.to_s
    end

    return time, record
  end

end


end

# vim: sw=2 ts=2 et
