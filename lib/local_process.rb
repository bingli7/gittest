require 'common'

module CucuShift
  # handle lifecycle of local spawned process and it's IO
  # IO is handled in the most simple way - using a separate thread for each
  #   stream. That can be improved in the future using select over all processes
  #   streams and processing inside one thread or a thread pool. It would be a
  #   very distant future though.
  class LocalProcess
    include Common::Helper

    DEFAULT_TIMEOUT = 3600

    attr_reader :pid
    attr_accessor :exit_status, :wait_thread, :cmd, :opts
    private :exit_status=, :wait_thread=
    private :cmd, :opts, :cmd=, :opts=

    # launch a new process, needs adjustments for windows
    # @param cmd [String, Array] command as a single string or array see
    #   [Process#spawn]
    # @opts [Hash] other options
    def initialize(*cmd, **opts)
      self.cmd = cmd.dup
      self.opts = opts.dup
      @status = :pending

      log_text = "Shell Commands: "
      if opts[:env]
        log_text << opts[:env].inject("") { |r,e| r << e.join('=') << "\n" }
      end
      log_text << result[:command]
      logger.info(log_text) unless opts[:quiet]

      spawn
    end

    # @return [Hash] spawn options related to input streams
    private def pipes
      raise unless [ :starting, :pending ].include? @status
      res = {}

      ## deal with stdin
      case opts[:stdin]
      when nil
        res[:in] = :close
      when IO, Symbol
        res[:in] = opts[:stdin]
      when String
        @in_r,  @in_w  = IO.pipe
        @in_w.binmode if opts[:binmode]
        res[:in] = @in_r
        @in_writer_proc = proc {
          @in_w.write(opts[:stdin])
          @in_w.close
        }
      else
        raise "don't know how to handle stdin: #{opts[:stdin].class}"
      end

      ## deal with stdout
      case opts[:stdout]
      when nil
        @out_r, @out_w = IO.pipe
        @out_r.binmode if opts[:binmode]
        res[:out] = @out_w
        @out_reader_proc = proc do
          o = @out_r.read
          @out_r.close
          o
        end
      when IO, Symbol
        res[:out] = opts[:stdout]
      else
        raise "don't know how to handle stdout: #{opts[:stdout].class}"
      end

      ## deal with stderr
      if opts[:stderr].equal? opts[:stdout]
        res[:err] = [:child, :out]
      else
        case opts[:stderr]
        when nil
          @err_r, @err_w = IO.pipe
          @err_r.binmode if opts[:binmode]
          res[:err] = @err_w
          @err_reader_proc = proc do
            e = @err_r.read
            @err_r.close
            e
          end
        when IO, Symbol
          res[:err] = opts[:stderr]
        else
          raise "don't know how to handle stderr: #{opts[:stderr].class}"
        end
      end

      return res
    end

    private def spawn_opts
      return @spawn_opts if @spawn_opts

      @spawn_opts = { pgroup: true }
      @spawn_opts.merge! pipes
      @spawn_opts[:chdir] = opts[:chdir] if opts[:chdir]

      return @spawn_opts
    end

    private def pid=(val)
      @pid = val
      result[:pid] = val
    end

    private def handle_io
      raise unless @status == :starting

      @in_r.close if @in_r
      @out_w.close if @out_w
      @err_w.close if @err_w

      @out_reader = Thread.new &@out_reader_proc if @out_reader_proc
      @err_reader = Thread.new &@err_reader_proc if @err_reader_proc
      @in_writer = Thread.new &@in_writer_proc if @in_writer_proc
    end

    private def close_io
      [:@in_r, :@in_w, :@out_r, :@out_w, :@err_r, :@err_w]. each do |stream|
        s = instance_variable_get(stream)
        if s && !s.closed?
          s.close rescue nil
          unless s.closed?
            raise "could not close #{stream} for: #{result[:instruction]}"
          end
        end
      end
    end

    private def spawn
      raise unless @status == :pending
      @status = :starting

      self.pid = Process.spawn(*processed_cmd, spawn_opts)
      self.wait_thread = Process.detach(@pid)

      handle_io

      @status = :running
    rescue => e
      @status = :error
      close_io
      raise e
    end

    private def wait_timeout
      opts[:timeout] ? opts[:timeout].to_i : DEFAULT_TIMEOUT
    end

    private def processed_cmd
      pcmd = []
      # environment hash is first param according to docs
      pcmd << opts[:env] if opts[:env]
      pcmd.concat cmd.flatten
      return pcmd
    end

    def result
      return @res if @res

      command = cmd.flatten
      cmdstr = command.size == 1 ? command.first : command.to_s

      result = opts[:result] || {}
      result[:command] = cmdstr
      result[:instruction] = "\`#{cmdstr}\`"
      result[:success] = true
      result[:timeout] = false
      result[:process_object] = self

      @res = result
      return @res
    end

    def wait(timeout = nil)
      success = wait_for(timeout || wait_timeout) {
        finished?
      }
      unless success
        result[:timeout] = true
        logger.warn("process timeout") unless opts[:quiet]
        kill_tree
      end

      return result
    end

    def finished?
      return result[:exitstatus] if result[:exitstatus]

      thread_res = wait_thread.join(1)
      if thread_res
        begin
          result[:exitstatus] = thread_res.value.to_i
          result[:success] = result[:success] && result[:exitstatus] == 0

          if @out_reader
            result[:stdout] = @out_reader.join(3) && @out_reader.value
            unless result[:stdout]
              raise("stdout never closed of: #{result[:instruction]}")
            end
          end
          if @err_reader
            result[:stderr] = @err_reader.join(3) && @err_reader.value
            unless result[:stderr]
              raise("stderr never closed of: #{result[:instruction]}")
              end
          end
          result[:response] = result[:stdout].to_s

          unless opts[:quiet]
            logger.plain(result[:stdout], false)
            unless result[:stderr].equal?(result[:stdout])
              logger.plain(result[:stderr], false)
            end
            logger.info("Exit Status: #{result[:exitstatus]}")
          end

          @status = :finished
          return result
        ensure
          # ensure IO streams are in all circumstances closed but *after* we
          #   allowed IO threads to finish. Otherwise they will raise and
          #   process output will *not* be captured.
          close_io
        end
      end
      return false
    end

    def kill_tree
      return if @status == :finished

      unless finished?
        do_kill_tree
      end
    rescue => e
      # make sure we kill procs anyway
      do_kill_tree
      raise e
    end
    alias clean_up kill_tree

    def do_kill_tree
      #if /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
      if Gem.win_platform?
        raise "dunno how to handle this on windows"
        # TODO: investigate sys-proctable based solution
      else
        Process.kill(:TERM, -@pid) rescue nil
        sleep 5
        Process.kill(:KILL, -@pid) rescue nil
        sleep 1
        unless finished?
          raise("could not clean-up #{@pid} process: #{result[:command]}")
        end
      end
    ensure
      # Make sure to clean-up as much as possible but at the same time
      #   this clean-up should be *after* IO threads have completed (if at all
      #   possible). Otherwise they will raise and process output wont be
      #   captured.
      close_io
    end

    def to_s
      result[:instruction]
    end
  end
end
