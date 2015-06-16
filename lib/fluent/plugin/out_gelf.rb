module Fluent

class GELFOutput < BufferedOutput

  Plugin.register_output("gelf", self)

  config_param :use_record_host, :bool, :default => false
  config_param :add_msec_time, :bool, :default => false
  config_param :host, :string, :default => nil
  config_param :port, :integer, :default => 12201

  def initialize
    super
    require "gelf"
  end

  def configure(conf)
    super
    raise ConfigError, "'host' parameter required" unless conf.has_key?('host')
  end

  def start
    super
    @conn = GELF::Notifier.new(@host, @port, 'WAN')

    # Errors are not coming from Ruby so we use direct mapping
    @conn.level_mapping = 'direct'
    # file and line from Ruby are in this class, not relevant
    @conn.collect_file_and_line = false
  end

  def shutdown
    super
  end

  def format(tag, time, record)
    gelfentry = { :timestamp => time, :_tag => tag }

    record.each_pair do |k,v|
      case k
      when 'version' then
        gelfentry[:_version] = v
      when 'timestamp' then
        gelfentry[:_timestamp] = v
      when 'host' then
        if @use_record_host then gelfentry[:host] = v
        else gelfentry[:_host] = v end
      when 'name' then
        gelfentry[:facility] = v
      when 'msg' then
        gelfentry[:short_message] = v
      when 'level' then
        case "#{v}".downcase
        # bunyan levels
        when '10', 'trace' then gelfentry[:level] = GELF::DEBUG
        when '20', 'debug' then gelfentry[:level] = GELF::DEBUG
        when '30', 'info' then gelfentry[:level] = GELF::INFO
        when '40', 'warn' then gelfentry[:level] = GELF::WARN
        when '50', 'error' then gelfentry[:level] = GELF::ERROR
        when '60', 'fatal' then gelfentry[:level] = GELF::FATAL
        else gelfentry[:_level] = v
        end
      when 'msec' then
        # msec must be three digits (leading/trailing zeroes)
        if @add_msec_time then
          gelfentry[:timestamp] = (time.to_s + "." + v).to_f
        else
          gelfentry[:_msec] = v
        end
      end
    end

    gelfentry[:full_message] = Yajl.dump(record, { :pretty => true })

    gelfentry.to_msgpack
  end

  def write(chunk)
    chunk.msgpack_each do |data|
      @conn.notify!(data)
    end
  end

end


end

# vim: sw=2 ts=2 et
