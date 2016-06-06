#!/usr/bin/env ruby
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")

"""
Utility to launch OpenShift v3 instances
"""

require 'base64'
require 'cgi'
require 'commander'
require 'uri'
require 'yaml'

require 'collections'
require 'common'
require 'http'
require 'launchers/env_launcher'

module CucuShift
  class EnvLauncherCli
    include Commander::Methods
    include Common::Helper

    def initialize
      always_trace!
    end

    def run
      program :name, 'EnvLauncherCli'
      program :version, '0.0.1'
      program :description, 'Tool to launch OpenShift Environment'

      #Commander::Runner.instance.default_command(:gui)
      default_command :launch

      global_option('-c', '--config KEY',
                    "command specific:\n\t" <<
                    "* for OSE launcher selects config source\n\t" <<
                    "* for ec2_instance it selects custom setup script\n\t" <<
                    "* for template it specifies a file with YAML variables")
      global_option('-l', '--launched_instances_name_prefix PREFIX', 'prefix instance names; use string `{tag}` to have it replaced with MMDDb where MM in month, DD is day and b is build number; tag works only with PUDDLE_REPO')
      global_option('-d', '--user_data SPEC', "file containing user instances' data")
      global_option('-s', '--service_name', 'service name to lookup in config')
      global_option('-i', '--image_name IMAGE', 'image to launch instance with')
      global_option('--it', '--instance_type TYPE', 'instance flavor to launch')

      command :launch do |c|
        c.syntax = "#{File.basename __FILE__} launch -c [ENV|<conf keyword>]"
        c.description = 'launch an instance'
        c.option('-n', '--node_num', "number of nodes to launch")
        c.option('-m', '--master_num', "number of nodes to launch")
        c.action do |args, options|
          say 'launching..'
          case options.config
          when 'env', 'ENV'
            el = EnvLauncher.new

            ## set some opts based on Environment Variables
            options.master_num ||= Integer(getenv('MASTER_NUM')) rescue 1
            options.node_num ||= getenv('NODE_NUM').to_i
            options.launched_instances_name_prefix ||= getenv('INSTANCE_NAME_PREFIX')
            options.instance_type ||= getenv('CLOUD_INSTANCE_TYPE')
            options.image_name ||= getenv('CLOUD_IMAGE_NAME')
            options.service_name ||= getenv('CLOUD_SERVICE_NAME')
            options.service_name = options.service_name.to_sym
            options.puddle_repo ||= getenv("PUDDLE_REPO")

            # a hack to put puddle tag into instance names
            options.launched_instances_name_prefix =
              process_instance_name(options.launched_instances_name_prefix,
                                    options.puddle_repo)

            # TODO: allow specifying pre-launched machines

            ## set ansible launch options from environment
            launch_opts = host_opts(options)
            el.launcher_env_options(launch_opts)

            ## launch Cloud instances
            user_data_string = user_data(options.user_data, erb_vars: launch_opts)
            hosts = launch_instances(options, user_data: user_data_string)

            ## run ansible setup
            hosts_spec = { "master"=>hosts[0..options.master_num - 1],
                           "node"=>hosts[options.master_num..-1] }
            launch_opts[:hosts_spec] = hosts_spec
            el.ansible_install(**launch_opts)
          else
            raise "config keyword '#{options.config}' not implemented"
          end
        end
      end

      command :template do |c|
        c.syntax = "#{File.basename __FILE__} template -l <instance name>"
        c.description = 'launch instances according to template'
        c.action do |args, options|
          say 'launching..'
          launch_template(**options.default)
        end
      end

      command :ec2_instance do |c|
        c.syntax = "#{File.basename __FILE__} ec2_instance -l <instance name>"
        c.description = 'launch an instance with possibly an ansible playbook'
        c.action do |args, options|
          say 'launching..'
          options.service_name ||= :AWS
          options.service_name = options.service_name.to_sym
          unless options.service_name == :AWS
            raise "for the time being only AWS is supported"
          end

          launch_ec2_instance(options)
        end
      end

      run!
    end

    # TODO: remove
    def host_opts(options)
      {
        # hosts_spec will be ready only after actual instance launch

        # we no longer need to pass username and key as we build hosts_spec
        #   only with [CucuShift::Host] values
        # ssh_key: expand_private_path(conf[:services, options.service_name, :key_file] || conf[:services, options.service_name, :host_opts, :ssh_private_key]),
        # ssh_user: conf[:services, options.service_name, :host_opts, :user] || 'root',
        set_hostnames: !! conf[:services, options.service_name, :fix_hostnames]
      }
    end

    def get_dyn
      CucuShift::Dynect.new()
    end

    # @param erb_vars [Hash] additional variales for ERB user_data processing
    # @param spec [String] user data specification
    # @return [String] user data to pass to instance
    def user_data(spec = nil, erb_vars = {})
      ## process user data
      spec ||= getenv('INSTANCES_USER_DATA')
      if spec
        case spec
        when URI.regexp
          url = URI.parse spec
          if url.scheme == "file"
            # to specify relative path, do like "file://p1/p2/p3"
            # to specify absolure path, do like "file:///p1/p2/p3"
            path = url.host ? File.join(url.host, url.path) : url.path
            user_data_string =
              File.read( expand_private_path(path, public_safe: true) )
          elsif url.scheme =~ /http/
            res = Http.get(url: spec)
            unless res[:success]
              raise "failed to get url: #{spec}"
            end
            user_data_string = res[:response]
          else
            raise "dunno how to handle scheme: #{url.scheme}"
          end

          if url.path.end_with? ".erb"
            url_options = CGI::parse url.query
            url_options = Collections.map_hash(url_options) { |k, v|
              # all single value URL params would be de-arrayified
              [ k, v.size == 1 ? v.first : v ]
            }
            erb = ERB.new(user_data_string)
            # options from url take precenece before lauch options
            erb_binding = Common::BaseHelper.binding_from_hash(**launch_opts,
                                                               **erb_vars)
            user_data_string = erb.result(erb_binding)
          end
        else
          # raw user data
          user_data_string = spec
        end

        # TODO: gzip data?
      else
        user_data_string = ""
      end

      return user_data_string
    end

    # @return [Array<CucuShift::Host>] the launched and ssh acessible hosts
    def launch_instances(options,
                         user_data: nil)
      host_names = []
      if options.master_num > 1
        options.master_num.times { |i|
          host_names << options.launched_instances_name_prefix +
            "_master_#{i+1}"
        }
      else
        host_names << options.launched_instances_name_prefix + "_master"
      end
      options.node_num.times { |i|
        host_names << options.launched_instances_name_prefix +
          "_node_#{i+1}"
      }

      case conf[:services, options.service_name, :cloud_type]
      when "aws"
        raise "TODO service choice" unless options.service_name == :AWS
        ec2_image = options.image_name || ""
        ec2_image = ec2_image.empty? ? :raw : ec2_image
        amz = Amz_EC2.new
        create_opts = { user_data: Base64.encode64(user_data) }
        if options.instance_type && !options.instance_type.empty?
          create_opts[:instance_type] = options.instance_type
        end
        res = amz.launch_instances(tag_name: host_names, image: ec2_image,
                                   create_opts: create_opts)
      when "openstack"
        ostack = CucuShift::OpenStack.new(
          service_name: options.service_name
        )
        create_opts = {}
        create_opts[:image] = options.image_name if options.image_name
        if options.instance_type && !options.instance_type.empty?
          create_opts[:flavor_name] = options.instance_type
        end
        res = ostack.launch_instances(names: host_names,
                                      user_data: Base64.encode64(user_data),
                                      **create_opts)
      when "gce"
        gce = CucuShift::GCE.new

        boot_disk_opts = {}
        if options.image_name && !options.image_name.empty?
          boot_disk_opts[:initialize_params] = { img_snap_name: options.image_name }
        end

        instance_opts = {}
        if options.instance_type && !options.instance_type.empty?
          if options.instance_type.include? "/"
            instance_opts[:machine_type] = options.instance_type
          else
            instance_opts[:machine_type_name] = options.instance_type
          end
        end
        res = gce.create_instances(host_names, user_data: user_data, instance_opts: instance_opts, boot_disk_opts: boot_disk_opts )
      else
        raise "unknown service type: #{conf[:services, options.service_name, :cloud_type]}"
      end

      # we get here Array of [something, Host] pairs, convert to Array<Host>
      res = res.map(&:last)
      # wait for all hosts to become accessible
      res.each {|h| h.wait_to_become_accessible(600)}
      # return the hosts
      return res
    end

    # process instance name prefix to generate an identity tag
    # e.g. "2015-11-10.2" => "11102"
    # If "latest" build is used, then we try to find it on server.
    def process_instance_name(name_prefix, puddle_repo = nil)
      puddle_re = '\d{4}-\d{2}-\d{2}\.\d+'
      return name_prefix.gsub("{tag}") {
        case puddle_repo
        when nil
          raise 'no pudde repo specified, cannot substitute ${tag}'
        when /#{puddle_re}/
          # $& is last match
          $&.gsub(/[-.]/,'')[4..-1]
        when %r{(?<=/)latest/}
          # $` is string before last match
          puddle_base = $`
          res = Http.get(url: puddle_base)
          raise "failed to get puddle base: #{puddle_base}" unless res[:success]
          puddles = []
          res[:response].scan(/href="(#{puddle_re})\/"/) { |m| puddles << m[0] }
          raise "strange puddle base: #{puddle_base}" if puddles.empty?
          puddles.map! { |p| p.gsub!(/[-.]/,'') }
          latest = puddles.map(&:to_str).map(&:to_i).max
          latest.to_s[4..-1]
        else
          raise "cannot find puddle base from url: #{puddle_repo}"
        end
      }
    end

    # path and basepath can be URLs
    def readfile(path, basepath=nil)
      case path
      when %r{\Ahttps?://}
        return Http.get(url: path, raise_on_error: true)[:response]
      when %r{\A/}
        return File.read path
      else
        if ! basepath
          return File.read expand_private_path(path, public_safe: true)
        else
          with_base = File.join(basepath, path)
          return (readfile(with_base) rescue readfile(path))
        end
      end
    end

    def basename(path_or_url)
      File.basename(URI.parse(path_or_url).path)
    end

    def localize(path, basepath=nil)
      case path
      when %r{\Ahttps?://}
        filename = basename(path)
        unless filename =~ /\A[-a-zA-Z0-9._]+\z/
          raise "bad filename '#{filename}' for URL: #{path}"
        end
        filename = Host.localhost.absolutize(filename)
        File.write(filename, Http.get(path, raise_on_error: true)[:response])
        return filename
      when %r{\A/}
        return path
      else
        if ! basepath
          return expand_private_path(path, public_safe: true)
        else
          with_base = File.join(basepath, path)
          return (localize(with_base) rescue localize(path))
        end
      end
    end


    def merged_launch_opts(common, overrides)
      common ||= {}
      overrides ||= {}
      service_name = overrides[:service_name] || common[:service_name]
      if service_name
        service_name = service_name.to_sym
      else
        raise "no service name specified for host launch options"
      end

      common_launch_opts = common[service_name] || {}
      overrides_launch_opts = overrides[service_name] || {}
      return service_name,
        Collections.deep_merge(common_launch_opts, overrides_launch_opts)
    end

    def dns_component
      @dns_component ||= CucuShift::Dynect.gen_timed_random_component
    end

    def launch_host_group(host_group, common_launch_opts, user_data_vars: {})
      # generate instance names
      host_name_prefix = common_launch_opts[:name_prefix]
      host_roles = host_group[:roles]
      host_names = host_group[:num].times.map {|i| host_name_prefix + host_roles.join("-") + "-" + (i + 1).to_s}

      # get launch instances config
      service_name, launch_opts = merged_launch_opts(common_launch_opts, host_group[:launch_opts])

      # get user data
      if launch_opts[:user_data]
        user_data_string = user_data(launch_opts[:user_data], user_data_vars)
      else
        user_data_string = ""
      end
      launch_opts.delete(:user_data)

      service_type = conf[:services, service_name, :cloud_type]
      launched = case service_type
      when "aws"
        raise "TODO service choice" unless service_name == :AWS
        amz = Amz_EC2.new
        launch_opts[:user_data] = Base64.encode64(user_data_string)
        res = amz.launch_instances(tag_name: host_names,
                                   image: launch_opts.delete(:image),
                                   create_opts: launch_opts)
      when "openstack"
        ostack = CucuShift::OpenStack.new(service_name: service_name)
        create_opts = {}
        res = ostack.launch_instances(
          names: host_names,
          user_data: Base64.encode64(user_data_string),
          **launch_opts
        )
      when "gce"
        gce = CucuShift::GCE.new
        res = gce.create_instances(host_names, user_data: user_data_string,
                                   **launch_opts )
      else
        raise "unknown service type #{service_type} for cloud #{service_name}"
      end

      # set hostnames if cloud has broken defaults
      fix_hostnames = conf[:services, service_name, :fix_hostnames]
      launched.map(&:last).each do |host|
        host[:fix_hostnames] = fix_hostnames
        host.roles.concat host_group[:roles]
      end

      return launched
    end

    def launcher_binding
      binding
    end

    # symbolize keys in launch templates
    def symbolize_template(template)
      template = Collections.deep_hash_symkeys template
      template[:hosts][:list].map! {|hg| Collections.deep_hash_symkeys hg}
      template[:install_sequence].map! {|is| Collections.deep_hash_symkeys is}
      return template
    end

    def run_ansible_playbook(playbook, inventory, env: nil, retries: 1)
      env ||= {}
      env = env.reduce({}) { |r,e| r[e[0].to_s] = e[1].to_s; r }
      env["ANSIBLE_FORCE_COLOR"] = "true"
      env["ANSIBLE_CALLBACK_WHITELIST"] = 'profile_tasks'
      retries.times do |attempt|
        id_str = (attempt == 0 ? ': ' : " (try #{attempt + 1}): ") + playbook
        say "############ ANSIBLE RUN#{id_str} ############################"
        res = Host.localhost.exec(
          'ansible-playbook', '-v', '-i', inventory,
          playbook,
          env: env, single: true, stderr: :out, stdout: STDOUT, timeout: 36000
        )
        say "############ ANSIBLE END#{id_str} ############################"
        if res[:success]
          break
        elsif attempt >= retries - 1
          raise "ansible failed execution, see logs" unless res[:success]
        end
      end
    end

    # performs an installation task
    def installation_task(task, erb_binding: binding, config_dir: nil)
      case task[:type]
      when "dns_hostnames"
        begin
          changed = false
          dyn = get_dyn
          erb_binding.local_variable_get(:hosts).each do |host|
            if !host.has_hostname?
              changed = true
              host[:fix_hostnames] = true
              dns_record = host[:cloud_instance_name] || rand_str(3, :dns)
              dns_record = dns_record.gsub("_","-")
              dns_record = "#{dns_record}.#{dns_component}"
              dyn.dyn_create_a_records(dns_record, host.ip)
            end
          end
          dyn.publish if changed
        ensure
          dyn.close if changed
        end
      when "wildcard_dns"
        begin
          dyn = get_dyn

          hosts = erb_binding.local_variable_get(:hosts)
          ips = hosts.select {|h| h.has_any_role? task[:roles]}.map(&:ip)
          dns_record = "*.#{dns_component}"
          fqdn = dyn.dyn_create_a_records(dns_record, ips)
          if task[:store_in]
            erb_binding.local_variable_set task[:store_in].to_sym, fqdn
          end
          dyn.publish
        ensure
          dyn.close
        end
      when "playbook"
        inventory_erb = ERB.new(readfile(task[:inventory], config_dir))
        inventory_erb.filename = task[:inventory]
        inventory_str = inventory_erb.result(erb_binding)
        inventory = Host.localhost.absolutize basename(task[:inventory])
        puts "Ansible inventory #{File.basename inventory}:\n#{inventory_str}"
        File.write(inventory, inventory_str)
        run_ansible_playbook(localize(task[:playbook]), inventory,
                             retries: (task[:retries] || 1), env: task[:env])
      end
    end

    # @param config [String] an YAML file to read variables from
    # @param launched_instances_name_prefix [String]
    def launch_template(config:, launched_instances_name_prefix:)
      vars = YAML.load(readfile(config))
      if ENV["LAUNCHER_VARS"] && !ENV["LAUNCHER_VARS"].empty?
        vars.merge!(YAML.load(ENV["LAUNCHER_VARS"]))
      end
      vars = Collections.deep_hash_symkeys vars
      vars[:instances_name_prefix] = launched_instances_name_prefix
      raise "specify 'template' in variables" unless vars[:template]

      config_dir = File.dirname config
      config_dir = nil if config_dir == "."
      hosts = []
      erb_binding = Common::BaseHelper.binding_from_hash(launcher_binding,
                                                         hosts: hosts, **vars)
      template = ERB.new(readfile(vars[:template], config_dir))
      template = YAML.load(template.result(erb_binding))
      template = symbolize_template(template)

      hosts_spec = template[:hosts]
      common_launch_opts = hosts_spec[:common_launch_opts]

      ## launch hosts
      hosts_spec[:list].each do |host_group|
        hosts.concat launch_host_group(
          host_group,
          common_launch_opts,
          user_data_vars: vars
        ).map(&:last)
      end
      # wait each host to become accessible
      hosts.each {|h| h.wait_to_become_accessible(600)}

      ## perform provisioning steps
      template[:install_sequence].each do |task|
        installation_task(task, erb_binding: erb_binding, config_dir: config_dir)
      end
    end

    def launch_ec2_instance(options)
      image = options.image_name || getenv('CLOUD_IMAGE_NAME')
      image = nil if image && image.empty?
      instance_name = options.launched_instances_name_prefix
      options.instance_type ||= getenv('CLOUD_INSTANCE_TYPE')
      if options.instance_type && !options.instance_type.empty?
        create_opts[:instance_type] = options.instance_type
      end
      if instance_name.nil? || instance_name.empty?
        raise "you must specify instance name with -l"
      end
      user_data = user_data(options.user_data)
      amz = Amz_EC2.new
      res = amz.launch_instances(tag_name: [instance_name], image: image,
                           create_opts: {user_data: Base64.encode64(user_data)},
                           wait_accessible: true)

      instance, host = res[0]
      unless host.kind_of? CucuShift::Host
        raise "bad return value: #{host.inspect}"
      end

      ## setup instance if there is a setup script
      setup = options.config
      unless setup
        # see if we have a setup script in config based on instance name
        scripts = conf[:services, options.service_name, :setup_scripts]
        if scripts
          image_name = instance.image.name
          setup = scripts.find { |e|
            image_name =~ e[:re]
          }
          setup = setup[:script] if setup
        end
      end
      if setup
        url = URI.parse setup
        path = expand_private_path(url.path, public_safe: true)
        query = url.query
        params = query ? CGI::parse(query) : {}
        Collections.map_hash!(params) { |k, v| [k, v.last] }
        setup_binding = Common::BaseHelper.binding_from_hash(binding, params)
        eval(File.read(path), setup_binding, path)
      end
    end
  end
end

if __FILE__ == $0
  CucuShift::EnvLauncherCli.new.run
end
