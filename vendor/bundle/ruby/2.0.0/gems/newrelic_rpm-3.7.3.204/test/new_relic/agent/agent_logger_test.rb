# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require 'new_relic/agent/agent_logger'
require 'new_relic/agent/null_logger'

class ArrayLogDevice
  def initialize( array=[] )
    @array = array
  end
  attr_reader :array

  def write( message )
    @array << message
  end

  def close; end
end


class AgentLoggerTest < Minitest::Test

  LEVELS = [:fatal, :error, :warn, :info, :debug]

  def setup
    NewRelic::Agent.config.apply_config(:log_file_path => "log/",
                                        :log_file_name => "testlog.log",
                                        :log_level => :info)
  end

  #
  # Tests
  #

  def test_initalizes_from_config
    logger = NewRelic::Agent::AgentLogger.new

    wrapped_logger = logger.instance_variable_get( :@log )
    logdev = wrapped_logger.instance_variable_get( :@logdev )
    expected_logpath = File.expand_path( NewRelic::Agent.config[:log_file_path] + NewRelic::Agent.config[:log_file_name] )

    assert_kind_of( Logger, wrapped_logger )
    assert_kind_of( File, logdev.dev )
    assert_equal( expected_logpath, logdev.filename )
  end

  def test_initalizes_from_override
    override_logger = Logger.new( '/dev/null' )
    logger = NewRelic::Agent::AgentLogger.new("", override_logger)
    assert_equal override_logger, logger.instance_variable_get(:@log)
  end

  def test_forwards_calls_to_logger
    logger = create_basic_logger

    LEVELS.each do |level|
      logger.send(level, "Boo!")
    end

    assert_logged(/FATAL/,
                  /ERROR/,
                  /WARN/,
                  /INFO/) # No DEBUG
  end

  def test_forwards_calls_to_logger_with_multiple_arguments
    logger = create_basic_logger

    LEVELS.each do |level|
      logger.send(level, "What", "up?")
    end

    assert_logged(/FATAL/, /FATAL/,
                  /ERROR/, /ERROR/,
                  /WARN/,  /WARN/,
                  /INFO/,  /INFO/) # No DEBUG
  end

  def test_forwards_calls_to_logger_once
    logger = create_basic_logger

    LEVELS.each do |level|
      logger.send(:log_once, level, :special_key, "Special!")
    end

    assert_logged(/Special/)
  end

  def test_wont_log_if_agent_not_enabled
    with_config(:agent_enabled => false) do
      logger = NewRelic::Agent::AgentLogger.new
      logger.warn('hi there')

      assert_kind_of NewRelic::Agent::NullLogger, logger.instance_variable_get( :@log )
    end
  end

  def test_does_not_touch_dev_null
    Logger.expects(:new).with('/dev/null').never
    with_config(:agent_enabled => false) do
      logger = NewRelic::Agent::AgentLogger.new
    end
  end

  def test_maps_log_levels
    assert_equal Logger::FATAL, NewRelic::Agent::AgentLogger.log_level_for(:fatal)
    assert_equal Logger::ERROR, NewRelic::Agent::AgentLogger.log_level_for(:error)
    assert_equal Logger::WARN,  NewRelic::Agent::AgentLogger.log_level_for(:warn)
    assert_equal Logger::INFO,  NewRelic::Agent::AgentLogger.log_level_for(:info)
    assert_equal Logger::DEBUG, NewRelic::Agent::AgentLogger.log_level_for(:debug)

    assert_equal Logger::INFO, NewRelic::Agent::AgentLogger.log_level_for("")
    assert_equal Logger::INFO, NewRelic::Agent::AgentLogger.log_level_for(:unknown)
  end

  def test_sets_log_level
    with_config(:log_level => :debug) do
      override_logger = Logger.new( $stderr )
      override_logger.level = Logger::FATAL

      logger = NewRelic::Agent::AgentLogger.new("", override_logger)

      assert_equal Logger::DEBUG, override_logger.level
    end
  end

  def test_log_to_stdout_and_warns_if_failed_on_create
    Dir.stubs(:mkdir).returns(nil)

    with_config(:log_file_path => '/someplace/nonexistent') do
      logger = with_squelched_stdout do
        NewRelic::Agent::AgentLogger.new
      end

      wrapped_logger = logger.instance_variable_get(:@log)
      logdev = wrapped_logger.instance_variable_get(:@logdev)

      assert_equal $stdout, logdev.dev
    end
  end

  def test_log_to_stdout_based_on_config
    with_config(:log_file_path => 'STDOUT') do
      logger = NewRelic::Agent::AgentLogger.new
      wrapped_logger = logger.instance_variable_get(:@log)
      logdev = wrapped_logger.instance_variable_get(:@logdev)

      assert_equal $stdout, logdev.dev
    end
  end

  def test_startup_purges_memory_logger
    LEVELS.each do |level|
      ::NewRelic::Agent::StartupLogger.instance.send(level, "boo!")
    end

    logger = create_basic_logger

    assert_logged(/FATAL/,
                  /ERROR/,
                  /WARN/,
                  /INFO/) # No DEBUG
  end

  def test_passing_exceptions_only_logs_the_message_at_levels_higher_than_debug
    logger = create_basic_logger

    begin
      raise "Something bad happened"
    rescue => err
      logger.error( err )
    end

    assert_logged(/ERROR : RuntimeError: Something bad happened/i)
  end

  def test_passing_exceptions_logs_the_backtrace_at_debug_level
    with_config(:log_level => :debug) do
      logger = create_basic_logger

      begin
        raise "Something bad happened"
      rescue => err
        logger.error( err )
      end

      assert_logged(/ERROR : RuntimeError: Something bad happened/i,
                    /DEBUG : Debugging backtrace:\n.*test_passing_exceptions/i)
    end
  end

  def test_format_message_allows_nil_backtrace
    with_config(:log_level => :debug) do
      logger = create_basic_logger

      e = Exception.new("Look Ma, no backtrace!")
      assert_nil(e.backtrace)
      logger.error(e)

      assert_logged(/ERROR : Exception: Look Ma, no backtrace!/i,
                    /DEBUG : No backtrace available./)
    end
  end

  def test_log_exception_logs_backtrace_at_same_level_as_message_by_default
    logger = create_basic_logger

    e = Exception.new("howdy")
    e.set_backtrace(["wiggle", "wobble", "topple"])

    logger.log_exception(:info, e)

    assert_logged(/INFO : Exception: howdy/i,
                  /INFO : Debugging backtrace:\n.*wiggle\s+wobble\s+topple/)
  end

  def test_log_exception_logs_backtrace_at_explicitly_specified_level
    logger = create_basic_logger

    e = Exception.new("howdy")
    e.set_backtrace(["wiggle", "wobble", "topple"])

    logger.log_exception(:warn, e, :info)

    assert_logged(/WARN : Exception: howdy/i,
                  /INFO : Debugging backtrace:\n.*wiggle\s+wobble\s+topple/)
  end

  def test_logs_to_stdout_if_fails_on_file
    Logger::LogDevice.any_instance.stubs(:open).raises(Errno::EACCES)

    logger = with_squelched_stdout do
      NewRelic::Agent::AgentLogger.new
    end

    wrapped_logger = logger.instance_variable_get(:@log)
    logdev = wrapped_logger.instance_variable_get(:@logdev)

    assert_equal $stdout, logdev.dev
  end

  def test_null_logger_works_with_impolite_gems_that_add_stuff_to_kernel
    Kernel.module_eval do
      def debug; end
    end

    logger = NewRelic::Agent::AgentLogger.new
    with_config(:agent_enabled => false) do
      logger.debug('hi!')
    end
  ensure
    Kernel.module_eval do
      remove_method :debug
    end
  end

  def test_should_cache_hostname
    Socket.expects(:gethostname).once.returns('cachey-mccaherson')
    logger = create_basic_logger
    logger.warn("one")
    logger.warn("two")
    logger.warn("three")
    host_regex = /cachey-mccaherson/
    assert_logged(host_regex, host_regex, host_regex)
  end

  #
  # Helpers
  #

  def logged_lines
    @logdev.array
  end

  def create_basic_logger
    @logdev = ArrayLogDevice.new
    override_logger = Logger.new(@logdev)
    NewRelic::Agent::AgentLogger.new("", override_logger)
  end

  def with_squelched_stdout
    orig = $stdout.dup
    $stdout.reopen( '/dev/null' )
    yield
  ensure
    $stdout.reopen( orig )
  end

  def assert_logged(*args)
    assert_equal(args.length, logged_lines.length)
    logged_lines.each_with_index do |line, index|
      assert_match(args[index], line)
    end
  end
end
