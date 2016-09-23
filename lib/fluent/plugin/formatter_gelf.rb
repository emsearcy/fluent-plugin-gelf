require 'fluent/formatter'

module Fluent
  module TextFormatter
    class GELFFormatter < Formatter
      Plugin.register_formatter("gelf", self)

      config_param :use_record_host, :bool, :default => true
      config_param :add_msec_time, :bool, :default => false

      def configure(conf)
        super
        require "gelf"
      end

      def format(tag, time, record)
        gelfentry = {
            :timestamp => time,
            :protocol => 1,
            :version => "1.0",
            :_tag => tag
        }

        record.each_pair do |k,v|
          case k
          when 'tag' then
            gelfentry[:_tag] = v
          when 'version' then
            gelfentry[:_version] = v
          when 'timestamp' then
            gelfentry[:_timestamp] = v
          when 'host' then
            if @use_record_host then gelfentry[:host] = v
            else gelfentry[:_host] = v end
          when 'level' then
            case "#{v}".downcase
            # emergency and alert aren't supported by gelf-rb
            when '0', 'emergency' then gelfentry[:level] = GELF::UNKNOWN
            when '1', 'alert' then gelfentry[:level] = GELF::UNKNOWN
            when '2', 'critical', 'crit' then gelfentry[:level] = GELF::FATAL
            when '3', 'error', 'err' then gelfentry[:level] = GELF::ERROR
            when '4', 'warning', 'warn' then gelfentry[:level] = GELF::WARN
            # gelf-rb also skips notice
            when '5', 'notice' then gelfentry[:level] = GELF::INFO
            when '6', 'informational', 'info' then gelfentry[:level] = GELF::INFO
            when '7', 'debug' then gelfentry[:level] = GELF::DEBUG
            else gelfentry[:_level] = v
            end
          when 'msec' then
            # msec must be three digits (leading/trailing zeroes)
            if @add_msec_time then 
              gelfentry[:timestamp] = "#{time.to_s}.#{v}".to_f
            else
              gelfentry[:_msec] = v
            end
          when 'short_message', 'full_message', 'facility', 'line', 'file' then
            gelfentry[k] = v
          else
            gelfentry['_'+k] = v
          end
        end
  
        if !gelfentry.has_key?('short_message') then
          if record.has_key?('message') then
            gelfentry[:short_message] = record['message']
          else
            gelfentry[:short_message] = record.to_json
          end
        end
        return gelfentry.to_json + "\0"
      end

    end
  end
end
