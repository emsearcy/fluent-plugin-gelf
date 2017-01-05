module Fluent

class GELFOutput < BufferedOutput
  class IdentityMap
    def self.[](x)
      x
    end
  end

  Plugin.register_output("gelf", self)

  config_param :use_record_host, :bool, :default => false
  config_param :add_msec_time, :bool, :default => false
  config_param :host, :string, :default => nil
  config_param :port, :integer, :default => 12201
  config_param :protocol, :string, :default => 'udp'
  # Default max_bytes is set to avoid Elasticsearch indexing errors.
  config_param :max_bytes, :integer, :default => 32000

  def initialize
    super
    require "gelf"
  end

  def configure(conf)
    super

    # a destination hostname or IP address must be provided
    raise ConfigError, "'host' parameter (hostname or address of Graylog2 server) is required" unless conf.has_key?('host')

    # choose protocol to pass to gelf-rb Notifier constructor
    # (@protocol is used instead of conf['protocol'] to leverage config_param default)
    if @protocol == 'udp' then @proto = GELF::Protocol::UDP
    elsif @protocol == 'tcp' then @proto = GELF::Protocol::TCP
    else raise ConfigError, "'protocol' parameter should be either 'udp' (default) or 'tcp'"
    end
  end

  def start
    super

    @conn = GELF::Notifier.new(@host, @port, 'WAN', {:facility => 'fluentd', :protocol => @proto})

    # Errors are not coming from Ruby so we use direct mapping
    @conn.level_mapping = IdentityMap
    # file and line from Ruby are in this class, not relevant
    @conn.collect_file_and_line = false
  end

  def shutdown
    super
  end

  def format(tag, time, record)
    if defined? Fluent::EventTime and time.is_a? Fluent::EventTime then
      timestamp = time.sec + (time.nsec.to_f/1000000000).round(3)
    else
      timestamp = time
    end

    gelfentry = { :timestamp => timestamp, :_tag => tag }

    record.each_pair do |k,v|
      # Truncate values longer than configured maximum
      v = v.bytesize > @max_bytes ? "#{v.byteslice(0, @max_bytes - 3)}..." : v

      case k
      when 'version' then
        gelfentry[:_version] = v
      when 'timestamp' then
        gelfentry[:_timestamp] = v
      when 'host' then
        if @use_record_host then gelfentry[:host] = v
        else gelfentry[:_host] = v end
      when 'level' then
        if v.is_a? Fixnum then gelfentry[:level] = v
        else
          case v.to_s.downcase
          when 'emergency' then gelfentry[:level] = 0
          when 'alert' then gelfentry[:level] = 1
          when 'critical', 'crit' then gelfentry[:level] = 2
          when 'error', 'err' then gelfentry[:level] = 3
          when 'warning', 'warn' then gelfentry[:level] = 4
          when 'notice' then gelfentry[:level] = 5
          when 'informational', 'info' then gelfentry[:level] = 6
          when 'debug' then gelfentry[:level] = 7
          else gelfentry[:_level] = v
          end
        end
      when 'msec' then
        # msec must be three digits (leading/trailing zeroes)
        if @add_msec_time then 
          gelfentry[:timestamp] = "#{time.to_s}.#{v}".to_f
        else
          gelfentry[:_msec] = v
        end
      when 'short_message', 'full_message', 'facility', 'line', 'file' then
        gelfentry[k.to_sym] = v
      else
        gelfentry["_#{k}".to_sym] = v
      end
    end

    if !gelfentry.has_key?(:short_message) or gelfentry[:short_message].to_s.empty? then
      # allow other non-empty fields to masquerade as the short_message if it is unset
      if gelfentry.has_key?(:_message) and !gelfentry[:_message].to_s.empty? then
        gelfentry[:short_message] = gelfentry.delete(:_message)
      elsif gelfentry.has_key?(:_msg) and !gelfentry[:_msg].to_s.empty? then
        gelfentry[:short_message] = gelfentry.delete(:_msg)
      elsif gelfentry.has_key?(:_log) and !gelfentry[:_log].to_s.empty? then
        gelfentry[:short_message] = gelfentry.delete(:_log)
      elsif gelfentry.has_key?(:_record) and !gelfentry[:_record].to_s.empty? then
        gelfentry[:short_message] = gelfentry.delete(:_record)
      else
        # we must have a short_message, so provide placeholder
        gelfentry[:short_message] = '(no message)'
      end
    end

    gelfentry.to_msgpack
  end

  def write(chunk)
    chunk.msgpack_each do |data|
      @conn.notify!(data)
    end
  end

  def formatted_to_msgpack_binary
    true
  end
end


end

# vim: sw=2 ts=2 et
