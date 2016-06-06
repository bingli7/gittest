#!/usr/bin/env ruby
require 'net/ssh'
require 'net/scp'
require 'fileutils'

module CucuShift
  module SSH
    module Helper
      # generate a key pair mainly useful for SSH but can be generic
      # will monkey patch a method to get public key in proper String format
      def self.gen_rsa_key
        key = OpenSSL::PKey::RSA.generate(2048)
        key.singleton_class.class_eval do
          def to_pub_key_string
            ::CucuShift::SSH::Helper.to_pub_key_string(self)
          end
        end

        return key
      end

      def self.to_pub_key_string(key)
        "#{key.ssh_type} #{[ key.to_blob ].pack('m0')}"
      end
    end

    class Connection
      include Common::Helper

      # @return [exit_status, output]
      def self.exec(host, cmd, opts={})
        ssh = self.new(host, opts)
        return ssh.exec(cmd)
      rescue => e
        # seems like connection initialization failed
        return { success: false,
                 instruction: "ssh #{opts[:user]}@#{host}",
                 error: e,
                 response: exception_to_string(e)
        }
      ensure
        ssh.close if defined?(ssh) and ssh
      end

      # @param [String] host the hostname to establish ssh connection
      # @param [Hash] opts other options
      # @note if no password and no private key are specified, we assume
      #   ssh is pre-configured to gain access
      def initialize(host, opts={})
        @host = host
        raise "ssh host is mandatory" unless host && !host.empty?

        @user = opts[:user] # can be nil for default username
        conn_opts = {keepalive: true}
        if opts[:private_key]
          logger.debug("SSH Authenticating with publickey method")
          private_key = expand_private_path(opts[:private_key])
          # this is not needed for ruby but help ansible and standalone ssh
          File.chmod(0600, private_key) rescue nil
          conn_opts[:keys] = [private_key]
          conn_opts[:auth_methods] = ["publickey"]
        elsif opts[:password]
          logger.debug("SSH Authenticating with password method")
          conn_opts[:password] = opts[:password]
          conn_opts[:auth_methods] = ["password"]
        else
          ## lets hope ssh is already pre-configured
          #logger.error("Please provide password or key for ssh authentication")
          #raise Net::SSH::AuthenticationFailed
        end
        begin
          @session = Net::SSH.start(host, @user, **conn_opts)
        rescue Net::SSH::HostKeyMismatch => e
          raise e if opts[:strict]
          e.remember_host!
          retry
        end
        @last_accessed = monotonic_seconds
      end

      def close
        @session.close unless closed?
      end

      def closed?
        return ! active?(verify: false)
      end

      def active?(verify: false)
        return @session && ! @session.closed? && (!verify || active_verified?)
      end

      # make sure connection was recently enough actually usable;
      #   otherwise perform a simple connection test;
      #   this is useful with keepalive: true when the host reboots
      private def active_verified?
        case
        when @last_accessed.nil?
          raise "ssh session initialization issue, we should never be here"
        when monotonic_seconds - @last_accessed < 120 # 2 minutes
          return true
        else
          res = exec("echo", timeout: 30, liveness: true)
          if res[:success]
            @last_accessed = monotonic_seconds
            return true
          else
            return false
          end
        end
      end

      def session
        # the assumption is that if somebody gets session, he would also call
        # something on it. So if a command or file transfer or something is
        # called then operation on success will prove session alive or will
        # cause session to show up as closed. If that assumption proves wrong,
        # we may need to find another way to update @last_accessed, perhaps
        # only inside methods that really prove session is actually alive.
        @last_accessed = monotonic_seconds
        return @session
      end

      # @param [String] local the local filename to upload
      # @param [String] remote the directory, where to upload
      def scp_to(local, remote)
        begin
          puts session.exec!("mkdir -p #{remote} || echo ERROR")
          session.scp.upload!(local, remote, :recursive=>true)
        rescue Net::SCP::Error
          logger.error("SCP failed!")
        end
      end

      # @param [String] remote the absolute path to be copied from
      # @param [String] local directory
      def scp_from(remote, local)
        begin
          FileUtils.mkdir_p local
          session.scp.download!(remote, local, :recursive=>true)
        rescue Net::SCP::Error
          logger.error("SCP failed!")
        end
      end

      def exec(command, opts={})
        # we want to have a handle over the result in case of error occurring
        # so that we catch any intermediate data for better reporting
        res = opts[:result] || {}

        # now actually execute the ssh call
        begin
          exec_raw(command, **opts, result: res)
        rescue => e
          # @last_accessed = 0
          res[:success] = false
          res[:error] = e
          res[:response] = exception_to_string(e)
        end
        if res[:stdout].equal? res[:stderr]
          output = res[:stdout]
        else
          output = "STDOUT:\n#{res[:stdout]}\nSTDERR:\n#{res[:stderr]}"
        end
        if res[:response]
          # i.e. an error was raised durig the call
          res[:response] = "#{output}\n#{res[:response]}"
        else
          res[:response] = output
        end

        unless res.has_key? :success
          res[:success] = res[:exitstatus] == 0 && ! res[:exitsignal]
        end

        return res
      end

      # TODO: use shell service for greater flexibility and interactive commands
      #       http://net-ssh.github.io/ssh/v1/chapter-5.html
      # TODO: allow setting environment variables via channel.env
      def exec_raw(command, opts={})
        raise "setting env variables not implemented yet" if opts[:env]

        res = opts[:result] || {}
        res[:command] = command
        instruction = 'Remote cmd: `' + command + '` @ssh://' +
                      ( @user ? "#{@user}@#{@host}" : @host )
        logger.info(instruction) unless opts[:quiet]
        res[:instruction] = instruction
        exit_status = nil
        stdout = res[:stdout] = opts[:stdout] || String.new
        stderr = res[:stderr] = opts[:stderr] || stdout
        exit_signal = nil
        channel = session.open_channel do |channel|
          channel.exec(command) do |ch, success|
            unless success
              res[:success] = false
              logger.error("could not execute command in ssh channel")
              abort
            end

            channel.on_data do |ch,data|
              stdout << data
            end

            channel.on_extended_data do |ch,type,data|
              stderr << data
            end

            channel.on_request("exit-status") do |ch,data|
              exit_status = data.read_long
            end

            channel.on_request("exit-signal") do |ch, data|
              exit_signal = data.read_long
            end

            if opts[:stdin]
              channel.send_data opts[:stdin].to_s
            end

            channel.eof!
          end
        end
        # launch a processing thread unless such is already running
        loop_thread!
        # wait channel to finish; nil or 0 means no timeout (wait forever)
        wait_since = monotonic_seconds
        while opts[:timeout].nil? ||
              opts[:timeout] == 0 ||
              monotonic_seconds - wait_since < opts[:timeout]
          break unless channel.active?
          # break unless active_verified? # useless with keepalive
          sleep 1
        end
        if channel.active?
          # looks like we hit the timeout
          channel.close
          if opts[:liveness]
            logger.warn("liveness check failed, may retry @#{@host}: #{command}")
          else
            logger.error("ssh channel timeout @#{@host}: #{command}")
          end
        end
        unless opts[:quiet]
          logger.plain(stdout, false)
          logger.plain(stderr, false) unless stdout == stderr
          logger.info("Exit Status: #{exit_status}")
        end

        # TODO: should we use mutex to make sure our view of `res` is updated
        #   according to latest @loop_thread updates?
        return res.merge!({ exitstatus: exit_status, exitsignal: exit_signal })
      end

      # launches a new loop/process thread unless we have one already running
      def loop_thread!
        unless @loop_thread && @loop_thread.alive?
          @loop_thread = Thread.new { session.loop }
        end
      end
    end
  end
end
