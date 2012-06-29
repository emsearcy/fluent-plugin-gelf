module Fluent

class GELF2FileOutput < BufferedOutput

  Plugin.register_output("gelf2file", self)    

  config_param :file_time_format, :string, :default => '%Y%m%d'
  config_param :path, :string, :default => nil

  def initialize
    super
    require 'time'
    @localtime = true
    @outfile = nil
  end

  def configure(conf)
    conf['buffer_chunk_limit'] ||= '256k'
    conf['flush_interval'] ||= '15s'

    super

    raise ConfigError, "'path' parameter is required on file output" unless conf.has_key?('path')

    # Support using UTC for path formatting, similar to time slice file plugin
    if conf['utc']
      @localtime = false
    elsif conf['localtime']
      @localtime = true
    end

  end

  def start
    super
    if @localtime then now = Time.new.strftime(@file_time_format)
    else now = Time.new.utc.strftime(@file_time_format) end
    @filepath = @path+now+".log"
    openlog
  end

  def shutdown
    super
    @outfile.close unless @outfile.nil?
  end

  def format(tag, time, record)
    if record.has_key?('full_message') then
      return record['full_message'] + "\n"
    elsif record.has_key?('short_message') then
      return record['short_message'] + "\n"
    else
      $log.warn "gelf2file: not a GELF record", :record => record.to_s
    end
  end

  def write(chunk)
    # See if we need to rotate file
    if @localtime then now = Time.new.strftime(@file_time_format)
    else now = Time.new.utc.strftime(@file_time_format) end
    if @path+now+".log" != @filepath then
      @filepath = @path+now+".log"
      openlog
    end

    # Write chunk
    chunk.write_to(@outfile)
    @outfile.flush
  end

  def openlog
    # Close old file (except when nil at startup)
    @outfile.close unless @outfile.nil?
    # Make sure parent dirs exist
    FileUtils.mkdir_p File.dirname(@filepath)
    # Open with new/current name
    @outfile = File.open(@filepath, "a")
  end

end


end

# vim: sw=2 ts=2 et
