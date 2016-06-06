require 'find'
require 'psych'
require 'uri'
require 'watir-webdriver'

  class Web4Cucumber
    attr_reader :base_url, :browser_type, :logger, :rules

    @@headless = nil

    FUNMAP = {
      :select => :select_lists,
      :checkbox => :checkboxes,
      :radio => :radios,
      :text_field => :text_fields,
      :textfield => :text_fields,
      :text_area => :textareas,
      :textarea => :textareas,
      :filefield => :file_fields,
      :file_field => :file_fields,
      :a => :as,
      :button => :button,
      :element => :elements,
      :input => :input
    }

    ELEMENT_TIMEOUT = 10

    # @param logger [Object] should have methods `#info`, `#warn`, `#error` and
    #   `#debug` defined
    def initialize(
        rules:,
        base_url:,
        logger: SimpleLogger.new,
        browser_type: :firefox,
        browser: nil
      )
      @browser_type = browser_type
      @rules = Web4Cucumber.load_rules [rules]
      @base_url = base_url
      @browser = browser
      @logger = logger
    end

    def is_new?
      !@browser
    end

    def browser
      return @browser if @browser
      firefox_profile = Selenium::WebDriver::Firefox::Profile.new
      chrome_profile = Selenium::WebDriver::Remote::Capabilities.chrome()
      if ENV.has_key? "http_proxy"
        proxy = ENV["http_proxy"].scan(/[\w\.\d\_\-]+\:\d+/)[0] # to get rid of the heading "http://" that breaks the profile
        firefox_profile.proxy = chrome_profile.proxy = Selenium::WebDriver::Proxy.new({:http => proxy, :ssl => proxy})
        firefox_profile['network.proxy.no_proxies_on'] = "localhost, 127.0.0.1"
        chrome_switches = %w[--proxy-bypass-list=127.0.0.1]
        ENV['no_proxy'] = '127.0.0.1'
      end
      client = Selenium::WebDriver::Remote::Http::Default.new
      client.timeout = 180

      headless

      if @browser_type == :firefox
        @browser = Watir::Browser.new :firefox, :profile => firefox_profile, :http_client=>client
      elsif @browser_type == :chrome
        @browser = Watir::Browser.new :chrome, desired_capabilities: chrome_profile, switches: chrome_switches
      else
        raise "Not implemented yet"
      end
      @browser
    end

    # start a new headless session if we don't have a GUI environment already;
    #   that means no windows, no mac, and no DISPLAY env variable;
    #   if you want to force headless on linux, just `unset DISPLAY` prior run
    def headless
      if !Gem.win_platform? &&
          /darwin/ !~ RUBY_PLATFORM &&
          !ENV["DISPLAY"] &&
          !@@headless
        require 'headless'
        @@headless = Headless.new
        @@headless.start
      end
    end

    def finalize
      @browser.close if @browser
      # avoid destroy as it happens at_exit anyway but often reused during run
      # @@headless.destroy if @@headless
    end

    def res_join(master_res, *results)
      results.each do |res|
        master_res.merge!(res) do |key, oldval, newval|
          case key
          when :success
            oldval && newval
          when :exitstatus
            newval
          when :instruction
            oldval
          else
            case oldval
            when String
              oldval << $/ << newval
            when CAN_APPEND
              oldval << newval
            when nil
              newval
            else
              raise "dunno how to merge result '#{key}' field: #{oldval}"
            end
          end
        end
      end
      return master_res
    end

    def run_action(action, **user_opts)
      logger.info("running web action #{action} ... ")
      unless rules[action.to_sym]
        raise "rules source have no #{action} rules"
      end
      result = {
        instruction: "perform web action '#{action}'",
        success: true,
        response: "performing web action '#{action}'",
        exitstatus: -1
      }
      rules[action.to_sym].each do |rule, spec|
        logger.info("#{rule}..")
        case rule
        when :url
          res_join result, handle_url(spec, **user_opts)
        when :element
          res_join result, handle_element(spec, **user_opts)
        when :elements
          res_join result, *spec.map { |el| handle_element(el, **user_opts) }
        when :action
          res_join result, handle_action(spec, **user_opts)
        when :scripts
          res_join result, *spec.map { |st| handle_script(st, **user_opts) }
        when :cookies
          res_join result, *spec.map {|ck| handle_cookie(ck,**user_opts) }
        when :with_window
          res_join result, handle_switch_window(spec, **user_opts)
        else
          raise "unknown rule '#{rule}'"
        end

        break unless result[:success]
      end

      result[:response] << $/ << "web action '#{action}' "
      result[:response] << (result[:success] ? "completed" : "failed")
      return result
    end

    def handle_cookie(cookie,**user_opts)
      unless cookie.kind_of? Hash
        raise "The script should be a Hash"
      end

      unless cookie.has_key?(:name) && cookie.has_key?(:expect_result)
        raise "Cookie lack of name or expect_result"
      end

      output = browser.cookies[cookie[:name]]
      if cookie[:expect_result].kind_of? String
        success = output == cookie[:expect_result]
      else
        success = ! output == ! cookie[:expect_result]
      end
      res = {
        instruction: "get cookie:\n#{cookie[:name]}\n\nexpected result: #{cookie[:expect_result].inspect}",
        success: success,
        response: output.to_s,
        exitstatus: -1
      }
      return res
    end

    def handle_script(script, **user_opts)
      unless script.kind_of? Hash
        raise "The script should be a Hash."
      end

      unless script.has_key?(:command) && script.has_key?(:expect_result)
        raise "Script lack of command or expect_result"
      end
      # sleep to make sure the ajax done, still no idea how much time should be
      sleep 1

      command = script[:command].gsub(/<([a-z_]+?)>/) { |match|
        user_opts[match[1..-2].to_sym] || match
      }
      output = execute_script(command)

      if script[:expect_result].kind_of? String
        expect = script[:expect_result].gsub(/<([a-z_]+?)>/) { |match|
          user_opts[match[1..-2].to_sym] || match
        }
        success = output == expect
      else
        success = ! output == ! script[:expect_result]
      end

      res = {
        instruction: "run JS:\n#{script[:command]}\n\nexpected result: #{script[:expect_result].inspect}",
        success: success,
        response: output.to_s,
        exitstatus: -1
      }
      return res
    end

    # window_rule[:selector] could be Regexp or String format of window's url/title
    # see the example in lib/rules/web/console/debug.xyaml
    def handle_switch_window(window_rule, **user_opts)
      unless window_rule.kind_of? Hash
        raise "switch window rule should be a Hash."
      end

      unless window_rule.has_key?(:selector) && window_rule.has_key?(:action)
        raise "switch window lack of selector or action"
      end

      if browser.window(window_rule[:selector]).exists?
        browser.window(window_rule[:selector]).use do
          return handle_action(window_rule[:action], **user_opts)
        end
      else
        for win in browser.windows
         logger.warn("window title: #{win.title}, window url: #{win.url}")
        end
        raise "specified window not found: #{window_rule[:selector].to_s}"
      end
    end

    def handle_action(action_body, **user_opts)
      case action_body
      when String, Symbol
        return run_action(action_body.to_sym, **user_opts)
      when Hash
        res_if = nil
        res_unless = nil

        if action_body[:if_element]
          res_if = handle_element(action_body[:if_element], **user_opts)
          unless res_if[:success]
            # element was not found but this is ok, we just return to caller
            res_if[:success] = true
            res_if[:response] << $/ << "skipping action #{action_body[:ref]}"
            return res_if
          end
        end

        if action_body[:unless_element]
          res_unless = handle_element(action_body[:unless_element], **user_opts)
          if res_unless[:success]
            # element was found so we quick return to caller
            res_unless[:response] << $/ << "skipping action #{action_body[:ref]}"
            return res_unless
          end
        end

        res = run_action(action_body[:ref].to_sym, **user_opts)
        res_join(res, res_if) if res_if
        res_join(res, res_unless) if res_unless
        return res
      else
        raise "unknown action rule body type: #{action_body.class}"
      end
    end

    def goto_url(url, **user_opts)
      url = url.gsub(/<([a-z_]+?)>/) { |match|
              user_opts[match[1..-2].to_sym] || match
            }

      if !(url =~ URI.regexp)
        url = URI.join(base_url, url).to_s
      end
      logger.info("Navigating to: #{url}")
      browser.goto url
      return {
        instruction: "opening #{url}",
        success: true,
        response: "opened #{url}",
        exitstatus: -1
      }
    end
    alias handle_url goto_url

    def handle_element(element_rule, **user_opts)
      unless element_rule.kind_of? Hash
        raise "Element rules should be a Hash but is: #{element_rule.inspect}"
      end
      # wait for element
      found, elements = wait_for_elements(element_rule.merge(
        # it's often useful to have paramaters inside selectors
        selector: selector_param_setter(element_rule[:selector], user_opts)
      ))

      res = {
        instruction: "handle #{element_rule}",
        success: !! ( found || element_rule[:optional] ),
        response: "element#{found ? "" : ' not'} found: #{element_rule}",
        exitstatus: -1
      }

      # save screenshot if required element not found
      unless found || element_rule[:optional]
        take_screenshot
      end

      # perform any operation over innermost element found
      op = element_rule[:op]
      if op && found
        # first element searched for, first field [the actual element list], last found element [this must be most inner element]
        element = elements.first.first.last
        res_join res, handle_operation(element, op, **user_opts)
      end

      return res
    end

    # @param element [Watir::Element]
    # @param op_spec [String] operation to perform on element defined in rules
    # @param user_opts [Hash] the options user provided for the operation, e.g.
    #   { :username => "my_username", :password => "my_password" }
    def handle_operation(element, op_spec, **user_opts)
      unless op_spec.kind_of? String
        raise "Op specification not a String: #{op_spec.inspect}"
      end

      op, space, val = op_spec.partition(" ")
      val.gsub!(/<([a-z_]+?)>/) { |match|
        user_opts[match[1..-2].to_sym] || match
      }

      res = {
        instruction: "#{op} #{element} with #{val}",
        response: "#{op} on #{element} with #{val}",
        success: true,
        exitstatus: -1
      }

      begin
        case op
        when "click"
          raise "cannot #{op} with a value" unless val.empty?
          element.send(op.to_sym)
        when "clear"
          raise "cannot #{op} with a value" unless val.empty?
          element.to_subtype.clear
        when "set", "select_value", "append"
          if element.kind_of?(Watir::Input)
            raise "maybe you meant to use `send_keys` op"
          end

          if element.respond_to? op.to_sym
            element.send(op.to_sym, val)
          else
            raise "element type #{element.class} does not support #{op}"
          end
        when "send_keys"
          # see http://watirwebdriver.com/sending-special-keys
          # to allow multiple values and special keys, value must parse to valid
          #   YAML; e.g. `mystring`, `:mysym`, [":asdsdf", "sdf", ":fsdf"]`
          raise "you must specify value for op #{op}" if val.empty?
          keys = Psych.load val
          element.send_keys keys
        else
          raise "do not know how to '#{op}'"
        end
      rescue => err
        res[:success] = false
        res[:response] << "\n" << "operation #{op} failed:\n"
        res[:response] << self.class.exception_to_string(err)
      ensure
        return res
      end
    end

    # TODO
    def take_screenshot
      #FileUtils.mkdir_p("screenshots")
      #screenshot = File.join("screenshots", "error.png")
      #@@b.driver.save_screenshot(screenshot)
      #File::open("screenshots/output.html", 'w') {
      #  |f| f.puts(@@b.html).
      #}
    end

    def get_elements(type, selector)
      type = type ? type.to_sym : :element # generic element when type absent

      raise "unknown web element type '#{type}'" unless FUNMAP.has_key? type

      # note that this is lazily evaluated so errors may occur later
      res = browser.public_send(FUNMAP[type], selector)

      # we want to always return an array
      if res.nil?
        res = []
      elsif res.kind_of? Watir::ElementCollection
        # sometimes non-existing element is returned, workaround that
        res = res.to_a.select { |e| e.exists? }
      else
        # some element types/methods return a single element
        res = res.exists? ? [res] : []
      end
      logger.info("found #{res.size} #{type} elements with selector: #{selector}")
      return res
    end

    def get_visible_elements(type, selector)
      return get_elements(type, selector).select { |e| e.present? }
    end

    # return HTML code of current page
    def page_html
      return browser.html
    end

    # @param element_list [Array] list of parametrized element type/selector
    #   pairs where selectors may contain `<param>` strings
    # @param params [Hash] params to replace within selectors
    # @return [Array] list of processed element type/selector pairs
    private def element_list_param_setter(element_list, params)
      element_list.map do |el_type, selector|
        [el_type, selector_param_setter(selector, params)]
      end
    end

    # @param selector [Hash] element selector as accepted by watir and may
    #   contain `<param>` strings
    # @param params [Hash] params to replace within selector
    # @return [Hash] processed element selector as accepted by watir
    private def selector_param_setter(selector, params)
      return selector if params.empty?
      selector_res = {}
      selector.each do |selector_type, query|
        selector_res[selector_type] =
          query.gsub(/<([a-z_]+)>/) { |m| params[$1.to_sym] || m }
      end
      return selector_res
    end

    # this somehow convoluted method can be used to wait for multiple elements
    #   for a given timeout; that means there is one timeout to get all of the
    #   requested elements
    # @param opts [Hash] with possible keys: :type, :selector, :list, :visible,
    #   :timeout
    # @return [Array] of `[status, [[[elements], type, selector], ..] ]`
    def wait_for_elements(opts)
      # expect either :list of [:type, :selector] pairs or
      #   :type and :selector options to be provided
      elements = opts[:list] || [[ opts[:type], opts[:selector] ]]
      only_visible = opts.has_key?(:visible) ? opts[:visible] : true
      timeout = opts[:timeout] || ELEMENT_TIMEOUT # in seconds

      start = Time.now
      result = nil
      begin
        result = {:list => [], :success => true}
        break if elements.all? { |type, selector|
          e = only_visible ?
              get_visible_elements(type, selector) :
              get_elements(type, selector)
          result[:list] << [e, opts[:type], opts[:selector]] unless e.empty?
        }
        result[:success] = false
      end while Time.now - start < timeout && sleep(1)

      return result[:success], result[:list]
    end
    alias wait_for_element wait_for_elements

    # parse CucuShift webauto single rules file; that is a YAML file with the
    #   only difference that duplicate keys on the second level are allowed;
    #   i.e. we can specify multiple `url`, `elements`, `action`, etc. child
    #   elements inside action rules
    # @param file [String] webauto XYAML file
    # @return [Hash] of the parsed data
    def self.parse_rules_file(file)
      # mid-level API to get document AST
      doc = Psych.parse_file(file)
      unless doc.root.kind_of? Psych::Nodes::Mapping
        raise "document root not a mapping: #{file}"
      end
      actions = doc.root.children
      res = {}
      actions.each_slice(2) do |key_ast, value_ast|
        key = key_ast.value.to_sym
        action_rules = []
        unless value_ast.kind_of? Psych::Nodes::Mapping
          raise "not a mapping: #{key} in #{file}"
        end
        value_ast.children.each_slice(2) { |rule_type, rule_body|
          action_rules << [rule_type.value.to_sym, symkeys(rule_body.to_ruby)]
        }
        if res[key]
          raise "duplicate action '#{key}' definition in #{file}"
        end
        res[key] = action_rules
      end
      return res
    end

    # traverse arrays and hashes to make all hash keys Symbols
    def self.symkeys(struc)
      case struc
      when Array
        struc.map! {|el| symkeys el}
        return struc
      when Hash
        target = {}
        struc.each { |k, v| target[k.to_sym] = symkeys(v) }
        return target
      else
        return struc
      end
    end

    def self.exception_to_string(e)
      str = "#{e.inspect}\n    #{e.backtrace.join("\n    ")}"
      e = e.cause
      while e do
        str << "\nCaused by: #{e.inspect}\n    #{e.backtrace.join("\n    ")}"
        e = e.cause
      end
      return str
    end

    def self.load_rules(*sources)
      return sources.flatten.reduce({}) { |rules, source|
        if source.kind_of? Hash
        elsif File.file? source
          source = parse_rules_file source
        elsif File.directory? source
          files = []
          if source.end_with? "/"
            # we should be recursive
            Find.find(source) { |path|
              if File.file?(path) && path.end_with?(".xyaml",".xyml")
                files << path
              end
            }
          else
            # we should only load .xyaml files in current dir
            files << Dir.entries(source).select {|d| File.file?(d) && d.end_with?(".xyaml",".xyml")}
          end

          source = load_rules(files)
        else
          raise "unknown rules source '#{source.class}': #{source}"
        end

        rules.merge!(source) { |key, v1, v2|
          raise "duplicate key '#{key}' in rules: #{sources}"
        }
      }
    end

    def execute_script(script)
      unless script.include?("return")
        raise "The script not contain the keyword return"
      end
      browser.execute_script(script)
    end

    class SimpleLogger
      def info(msg)
        Kernel.puts msg
      end
      alias error info
      alias warn info
      alias debug info
    end

    class CAN_APPEND
      def self.===(other)
        other.respond_to?(:<<)
      end
    end

  end
