# should not require 'common'
# should only include helpers that do NOT load any other cucushift classes

module CucuShift
  module Common
    module BaseHelper
      def to_bool(param)
        return false unless param
        if param.kind_of? String
          return !!param.downcase.match(/^(true|t|yes|y|on|[0-9]*[1-9][0-9]*)$/i)
        elsif param.respond_to? :empty?
          # true for non empty maps and arrays
          return ! param.empty?
        else
          # lets be more conservative here
          return !!param.to_s.downcase.match(/^(true|yes|on)$/)
        end
      end

      def word_to_num(which)
        if which =~ /first|default/
          return 0
        elsif which =~ /other|another|second/
          return 1
        elsif which =~ /third/
          return 2
        elsif which =~ /fourth/
          return 3
        elsif which =~ /fifth/
          return 4
        end
        raise "can't translate #{which} to a number"
      end

      # normalize strings used for keys
      # @param [String] key the key to be converted
      # @return string converted to a Symbol key
      def str_to_sym(key)
        return key if key.kind_of? Symbol
        return key.gsub(" ", "_").sub(/^:/,'').to_sym
      end

      def exception_to_string(e)
        str = "#{e.inspect}\n    #{e.backtrace.join("\n    ")}"
        e = e.cause
        while e do
          str << "\nCaused by: #{e.inspect}\n    #{e.backtrace.join("\n    ")}"
          e = e.cause
        end
        return str
      end

      def rand_str(length=8, compat=:nospace_sane)
        raise if length < 1

        result = ""
        array = []

        case compat
        when :dns
          #  matching regex [a-z0-9]([-a-z0-9]*[a-z0-9])?
          #  e.g. project name (up to 63 chars)
          for c in 'a'..'z' do array.push(c) end
          for n in '0'..'9' do array.push(n) end
          array << '-'

          result << array[rand(36)] # needs to start with non-hyphen
          (length - 2).times { result << array[rand(array.length)] }
          result << array[rand(36)] # end with non-hyphen
        when :dns952
          # matching regex [a-z]([-a-z0-9]*[a-z0-9])?
          # e.g. service name (up to 24 chars)
          for c in 'a'..'z' do array.push(c) end
          for n in '0'..'9' do array.push(n) end
          array << '-'

          result << array[rand(26)] # start with letter
          (length - 2).times { result << array[rand(array.length)] }
          result << array[rand(36)] # end with non-hyphen
        when :num
          "%0#{length}d" % rand(10 ** length)
        else # :nospace_sane
          for c in 'a'..'z' do array.push(c) end
          for c in 'A'..'Z' do array.push(c) end
          for n in '0'..'9' do array.push(n) end

          # avoid hiphen in the beginning to not confuse cmdline
          result << array[rand(array.length)] # begin with non-hyphen
          array << '-' << '_'

          (length - 1).times { result << array[rand(array.length)] }
        end

        return result
      end

      # replace <something> strings inside strings given option hash with symbol
      #   keys
      # @param [String] str string to replace
      # @param [Hash] opts hash options to use for replacement
      def replace_angle_brackets!(str, opts)
        str.gsub!(/<(.+?)>/) { |m|
          opt_key = m[1..-2].to_sym
          opts[opt_key] || raise("need to provide '#{opt_key}' REST option")
        }
      end

      # platform independent way to get monotonic timer seconds
      def monotonic_seconds
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def capture_error
        return true, yield
      rescue => e
        return false, e
      end

      # repeats block until it returns true or timeout reached; timeout not
      #   strictly enforced, use other timeout techniques to avoid freeze
      # @param seconds [Numeric] the max number of seconds to try operation to
      #   succeed
      # @param interval [Numeric] the interval to wait between attempts
      # @yield block the block will be yielded until it returns true or timeout
      #   is reached
      def wait_for(seconds, interval: 1, stats: nil)
        if seconds > 60
          Kernel.puts("waiting for operation up to #{seconds} seconds..")
        end
        iterations = 0

        start = monotonic_seconds
        success = false
        until monotonic_seconds - start > seconds
          iterations += 1
          success = yield and break
          sleep interval
        end

        if stats
          stats[:seconds] = monotonic_seconds - start
          stats[:full_seconds] = stats[:seconds].to_i
          stats[:iterations] = iterations
        end

        return success
      end

      # converts known label selectors to a [Array<String>] for use with cli
      #   commands
      # @param labels [String, Array] labels to filter on; e.g. you can use
      #   like `selector_to_label_arr(*hash, *array, str1, str2)`
      # @return [Array<String>]
      # @note it is somehow confusing to call this method properly, examples:
      #   selector_to_label_arr(*hash_selector)
      #   selector_to_label_arr(*array_of_arrays_with_label_key_value_pairs)
      #   selector_to_label_arr(str_label1, str_label2, ...)
      #   selector_to_label_arr(*hash, str_label1, *arr1, arr2, ...) # first we
      #     have a Hash with label_key/label_value pairs, then a plain string
      #     label, then an array of arrays with one or two elements denoting
      #     label_key or label_key/label_value pairs and finally an array of
      #     with one or two elements denoting a label_key or a
      #     label_key/label_value pair
      def selector_to_label_arr(*sel)
        sel.map do |l|
          case l
          when String
            l
          when Array
            if l.size < 1 && l.size > 2
              raise "array parameters need to have 1 or 2 elements: #{l}"
            end

            if ! l[0].kind_of?(String) || (l[1] && ! l[1].kind_of?(String))
              raise "all label key value pairs passed should be strings: #{l}"
            end

            if l[0].include?('=') || (l[1] && l[1].include?('='))
              raise "only accept expanded label selector arrays, e.g. selector_to_label_arr(*arry); either that or your label request is plain wrong: key='#{l[0]}' val='#{l[1]}'"
            end

            str_l = l[0].to_s.dup
            str_l << "=" << l[1].to_s unless l[1].nil?
            str_l
          when Hash
            raise 'to pass hashes, expand them with star, e.g. `*hash`'
          else
            raise "cannot convert labels to string array: #{sel}"
          end
        end
      end

      # test if a stirng is a number or not
      # @return float of int equivalent if the val is a number otherwise return val unmodified
      def str_to_num(val)
        num = Integer(val) rescue nil
        num = Float(val) rescue nil unless num
        return num if num
        return val
      end

      # @return [Binding] a binding empty from local variables
      def self.clean_binding
        binding
      end

      # @return [Binding] a binding with local variables set from a hash
      def self.binding_from_hash(b = nil, vars)
        b ||= self.clean_binding
        vars.each do |k, v|
          b.local_variable_set k.to_sym, v
        end
        return b
      end

      def getenv(var_name, strip: true, empty_is_nil: true)
        v = ENV[var_name]
        if v.nil? || empty_is_nil && v.empty?
          return nil
        else
          v = v.strip if strip
          return v
        end
      end
    end
  end
end
