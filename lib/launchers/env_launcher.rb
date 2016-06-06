require 'socket'
require 'erb'
require 'yaml'

# for file and params parsing
require 'uri'
require 'cgi'

require 'collections'
require 'common'
require 'host'

module CucuShift
  class EnvLauncher
    include Common::Helper

    ALTERNATING_AUTH = ['LDAP', 'KERBEROS']

    # raise on failing [CucuShift::ResultHash]
    private def check_res(res)
      unless res[:success]
        logger.error res[:response]
        raise "last operation failed: #{res[:instruction]}"
      end
    end


    # @param hosts [Hash<String,Array<Host>>] the hosts hash
    # @return [Array<String>] of size 2 like:
    #   `["master:host1,...,node:hostX", "master:ip1,...,node:ipX"]`
    private def hosts_to_specstr(hosts)
      hosts_str = []
      ips_str = []
      hosts.each do |role, role_hosts|
        role_hosts.each do |host|
          hosts_str << "#{role}:#{host.hostname}"
          ips_str << "#{role}:#{host.ip}"
        end
      end
      return hosts_str.join(','), ips_str.join(',')
    end

    # @param spec [String, Hash<String,Array>] the specification.
    #   If [String], then it looks like: `master:hostname1,node:hostname2,...`;
    #   If [Hash], then it's `role=>[host1, ..,hostN] pairs`;
    #   hostN might be a [String] hostname or [CucuShift::Host] (so we do nothing)
    private def spec_to_hosts(spec, ssh_key:, ssh_user:)
      hosts={}

      if spec.kind_of? String
        res = {}
        spec.gsub!(/all:/, 'master:')
        spec.split(',').each { |p|
          role, _, hostname = p.partition(':')
          (res[role] ||= []) << hostname
        }
        spec = res
      end

      host_opts = {user: ssh_user, ssh_private_key: ssh_key}
      spec.each do |role, hostnames|
        hosts[role] = hostnames.map do |hostname|
          if hostname.kind_of?(Host)
            hostname
          elsif !key || !ssh_user
            raise "you need to pass in :ssh_key and ssh_user if hosts_spec contains String hostnames (not CucuShift::Host)"
          else
            SSHAccessibleHost.new(hostname, host_opts)
          end
        end
      end

      return hosts
    end

    # @param hosts_spec [String, Hash<String,Array>] the specification.
    #   If [String], then it looks like: `master:hostname1,node:hostname2,...`;
    #   If [Hash], then it's `role=>[host1, ..,hostN] pairs`;
    #   hostN might be a [String] hostname or [CucuShift::Host];
    #   if using a [String] hostN, then ssh_user and ssh_key opts are mandatory
    # @param auth_type [String] LDAP, HTTPASSWD, KERBEROS
    # @param ssh_user [String] the username to use for ssh to env hosts;
    #   might be nil if receiving CucuShift::Host in spec
    # @param ssh_key [String] the private ssh key path to use for ssh to hosts;
    #   might be nil if receiving CucuShift::Host in spec
    # @param dns [String] the dns server to use; can be keyword or an IP
    #   address; see the dns case/when construct for available options
    # @param generate_hostnames [Symbol, String] see #generate_hostnames
    # @param set_hostnames [Boolean] whether or not to set machine hostname and
    #   add openshift_hostname to host lines
    # @param app_domain [String] domain used to generate route dns names;
    #   can be auto-sensed in certain setups, see dns code below
    # @param host_domain [String] domain used to access env hosts; not always
    #   used, see dns code below
    # @param rhel_base_repo [String] rhel/centos base repo URL to configure on
    #   env hosts
    # @param deployment_type [String] ???
    # @param image_pre [String] image pattern (see configure_env.sh)
    # @param pre_ansible [String] path + optional url query string, e.g.
    #   my/path?key1=val1&key2=val2 ; the params will be used as variables in the
    #   evaluated script
    # @param post_ansible [String] see #pre_ansible
    #
    def ansible_install(hosts_spec:, auth_type:,
                        ssh_key: nil, ssh_user: nil,
                        dns: nil, set_hostnames: false, generate_hostnames: :auto,
                        app_domain: nil, host_domain: nil,
                        rhel_base_repo: nil,
                        deployment_type:,
                        crt_path: nil,
                        image_pre:,
                        puddle_repo: nil,
                        etcd_num:,
                        pre_ansible: nil, post_ansible: nil,
                        ansible_url:,
                        use_rpm_playbook:,
                        use_nfs_storage:,
                        customized_ansible_conf: "",
                        kerberos_kdc: conf[:services, :test_kerberos, :kdc],
                        kerberos_keytab_url:
                          conf[:services, :test_kerberos, :keytab_url],
                        kerberos_admin_server:
                          conf[:services, :test_kerberos, :admin_server],
                        kerberos_docker_base_image:
                          conf[:sercices, :test_kerberos, :docker_base_image],
                        ldap_url: conf[:services, :test_ldap, :url])
      hosts = spec_to_hosts(hosts_spec, ssh_key: ssh_key, ssh_user: ssh_user)
      hostnames_str, ips_str = hosts_to_specstr(hosts)
      logger.info hostnames_str

      ose3_vars = []
      etcd_host_lines = []
      master_host_lines = []
      node_host_lines = []
      lb_host_lines = []
      nfs_host_lines = []

      dt1, dt2 = deployment_type.split(':', 2)
      openshift_pkg_version = ''
      case
      when dt2 && dt1 =~ /^[0-9.]*$/
        openshift_pkg_version = dt1
        deployment_type = dt2
      when !dt2
        # all is fine, non-versioned
      else
        raise "invalid deployment type string: #{deployment_type}"
      end

      # default cert dir is created by ansible installer:
      # 3.0.z: /etc/openshift
      # >=3.1: /etc/origin
      # When user did not specify openshift package verson, the latest
      # OpenShift RPM would be installed.
      if !openshift_pkg_version.empty?
        ose3_vars << "openshift_pkg_version=-#{openshift_pkg_version}"
      end

      if crt_path.nil? || crt_path.empty?
        crt_path = openshift_pkg_version.start_with?('3.0') ?
                                             '/etc/openshift' : '/etc/origin'
      end

      if !customized_ansible_conf.empty?
        ose3_vars << customized_ansible_conf
      end

      conf_script_dir = File.join(File.dirname(__FILE__), 'env_scripts')
      conf_script_file = File.join(conf_script_dir, 'configure_env.sh')

      hosts_erb = File.join(conf_script_dir, 'hosts.erb')

      conf_script = File.read(conf_script_file)

      conf_script.gsub!(/#CONF_HOST_LIST=.*$/,
                        "CONF_HOST_LIST=#{hostnames_str}")
      conf_script.gsub!(/#CONF_IP_LIST=.*$/, "CONF_IP_LIST=#{ips_str}")
      conf_script.gsub!(/#CONF_AUTH_TYPE=.*$/, "CONF_AUTH_TYPE=#{auth_type}")
      conf_script.gsub!(/#CONF_IMAGE_PRE=.*$/, "CONF_IMAGE_PRE='#{image_pre}'")
      conf_script.gsub!(/#CONF_CRT_PATH=.*$/) { "CONF_CRT_PATH='#{crt_path}'" }
      conf_script.gsub!(/#CONF_RHEL_BASE_REPO=.*$/,
                        "CONF_RHEL_BASE_REPO=#{rhel_base_repo}")


      conf_script.gsub!(/#(CONF_KERBEROS_ADMIN)=.*$/,
                        "\\1=#{kerberos_admin_server}")
      conf_script.gsub!(/#(CONF_KERBEROS_KEYTAB_URL)=.*$/,
                        "\\1=#{kerberos_keytab_url}")
      conf_script.gsub!(/#(CONF_KERBEROS_BASE_DOCKER_IMAGE)=.*$/,
                        "\\1=#{kerberos_docker_base_image}")
      conf_script.gsub!(/#(CONF_KERBEROS_KDC)=.*$/, "\\1=#{kerberos_kdc}")
      router_dns_type = nil
      dns_subst = proc do
        conf_script.gsub!(/#CONF_HOST_DOMAIN=.*$/,
                          "CONF_HOST_DOMAIN=#{host_domain}")
        conf_script.gsub!(/#CONF_APP_DOMAIN=.*$/,
                          "CONF_APP_DOMAIN=#{app_domain}")
        # relevant currently only for shared DNS config or router endpoints
        conf_script.gsub!(/#CONF_ROUTER_NODE_TYPE=.*$/,
                          "CONF_ROUTER_NODE_TYPE=#{router_dns_type}")
      end

      case auth_type
      when "HTPASSWD"
        identity_providers = "[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '#{crt_path}/htpasswd'}]"
      when "LDAP"
        identity_providers = %Q|[{"name": "LDAPauth", "login": "true", "challenge": "true", "kind": "LDAPPasswordIdentityProvider", "attributes": {"id": ["dn"], "email": ["mail"], "name": ["uid"], "preferredUsername": ["uid"]}, "bindDN": "", "bindPassword": "", "ca": "", "insecure":"true", "url": "#{ldap_url}"}]|
      when "KERBEROS"
        identity_providers = %Q|[{'name': 'requestheader', 'login': 'true', 'challenge': 'true', 'kind': 'RequestHeaderIdentityProvider', 'headers': ['X-Remote-User'], 'challengeURL': 'https://#{hosts['master'][0].hostname}/challenging-proxy/oauth/authorize?\${query}', 'loginURL': 'https://#{hosts['master'][0].hostname}/login-proxy/oauth/authorize?\${query}', 'clientCA': '/etc/origin/master/ca.crt'}]|
      else
        identity_providers = "[{'name': 'basicauthurl', 'login': 'true', 'challenge': 'true', 'kind': 'BasicAuthPasswordIdentityProvider', 'url': 'https://<serviceIP>:8443/validate', 'ca': '#{crt_path}master/ca.crt'}]"
      end

      ## lets sanity check auth type
      if auth_type != "LDAP" && auth_type != "KERBEROS" && hosts["master"].size > 1
        raise "multiple HA masters require LDAP or KERBEROS auth"
      end

      if set_hostnames
        ose3_vars << "openshift_set_hostname=true"
      end

      if puddle_repo
        conf_script.gsub!(/#(CONF_PUDDLE_REPO)=.*$/, "\\1='#{puddle_repo}'")
        ose3_vars << "openshift_additional_repos=[{'id': 'aos', 'name': 'ose-devel', 'baseurl': '#{puddle_repo}', 'enabled': 1, 'gpgcheck': 0}]"
      end

      ## Setup HA Master opt
      # * if non-HA master => router selector should point at nodes, num_infra should be == number of nodes, DNS should point at nodes
      # * if HA masters => router selector sohuld point at masters (region=infra), num_infra should be == number of masters, DNS should point at masters

      ## select load balancer node
      if hosts["master"].size > 1
        lb_node = hosts["node"].sample
        # TODO: can we use one of masters for a load balancer?
        raise "HA masters need a node for load balancer" unless lb_node
      end

      if hosts["master"].size > 1
        master_nodes_labels_str = %Q*openshift_node_labels="{'region': 'infra', 'zone': 'default'}" openshift_scheduleable=True*
        ose3_vars << "openshift_registry_selector='region=infra'"
        ose3_vars << "openshift_router_selector='region=infra'"
        router_dns_type = "master"
      elsif hosts.values.flatten.size > 1
        master_nodes_labels_str = "openshift_scheduleable=False"
        ose3_vars << "openshift_registry_selector='region=primary'"
        ose3_vars << "openshift_router_selector='region=primary'"
        router_dns_type = "node"
      else
        # this is all-in-one
        master_nodes_labels_str = %Q*openshift_node_labels="{'region': 'primary', 'zone': 'default'}"*
        ose3_vars << "openshift_registry_selector='region=primary'"
        ose3_vars << "openshift_router_selector='region=primary'"
        router_dns_type = "master"
      end
      router_ips = hosts[router_dns_type].map{|h| h.ip}
      # num_infra is not supported now, and introduce openshift_infra_nodes
      # https://bugzilla.redhat.com/show_bug.cgi?id=1303939
      # if openshift_infra_nodes is not set, by default its value is the number
      # of nodes with "region=infra" label
      if hosts["master"].size == 1
        ose3_vars << "openshift_infra_nodes=#{router_ips}"
      end

      ## Setup HA Master opts End

      ## DNS config
      case dns
      when nil, false, "", "none"
        # basically do nothing
        host_domain ||= "cluster.local"
        raise "specify :app_domain and :host_domain" unless app_domain
      #when "embedded"
      #  host_domain ||= "cluster.local"
      #  app_domain ||= rand_str(5, :dns) + ".example.com"
      #  conf_script.gsub!(
      #    /#CONF_DNS_IP=.*$/,
      #    "CONF_DNS_IP=#{hosts['master'][0].ip}"
      #  )
      #  conf_script.gsub!(/#USE_OPENSTACK_DNS=.*$/, "USE_OPENSTACK_DNS=true")
      when "embedded_skydns"
        host_domain ||= "cluster.local"
        app_domain = "router.cluster.local"
        conf_script.gsub!(
          /#CONF_DNS_IP=.*$/,
          "CONF_DNS_IP=#{hosts['master'][0].ip}"
        )
      when /^shared/
        host_domain ||= "cluster.local"
        app_domain ||= rand_str(5, :dns) + ".example.com"
        shared_dns_config = conf[:services, :shared_dns]
        conf_script.gsub!(
          /#CONF_DNS_IP=.*$/,
          "CONF_DNS_IP=#{shared_dns_config[:ip]}"
        )
        host_opts = {user: shared_dns_config[:user],
                     ssh_private_key: shared_dns_config[:key_file]}
        dns_host = SSHAccessibleHost.new(shared_dns_config[:ip], host_opts)
        begin
          dns_subst.call
          check_res \
            dns_host.exec_admin('cat > configure_env.sh', stdin: conf_script)
          check_res \
            dns_host.exec_admin('sh configure_env.sh configure_shared_dns')
        ensure
          dns_host.clean_up
        end
      when /^dyn$/
        require 'launchers/dyn/dynect'
        host_domain ||= "cluster.local"
        dyn = CucuShift::Dynect.new()

        begin
          if app_domain
            # validity of app zone up to the user that has set it
            dyn.dyn_create_a_records("*.#{app_domain}.", router_ips)
          else
            rec = dyn.dyn_create_random_a_wildcard_records(router_ips)
            app_domain = rec.sub(/^\*\./, '')
          end
          generate_hostnames(hosts, generate_hostnames) do |name, ip|
            dyn.dyn_create_a_records("#{name}.#{app_domain}.", ip)
          end

          dyn.publish
        ensure
          dyn.close
        end
      else
        host_domain ||= "cluster.local"
        raise "specify :app_domain and :host_domain" unless app_domain
        conf_script.gsub!(/#CONF_DNS_IP=.*$/, dns)
      end

      dns_subst.call # double substritution (if happens) should not hurt
      ## DNS config End

      #configure nfs on first master (for HA registry) if use_nfs_storage
      if use_nfs_storage
        nfs_host_lines << "#{hosts["master"][0].ansible_host_str}"

        ose3_vars << "openshift_hosted_registry_storage_kind=nfs"
        ose3_vars << "openshift_hosted_registry_storage_nfs_options='*(rw,root_squash,sync,no_wdelay)'"
        ose3_vars << "openshift_hosted_registry_storage_nfs_directory=/var/lib/exports"
        ose3_vars << "openshift_hosted_registry_storage_volume_name=regpv"
        ose3_vars << "openshift_hosted_registry_storage_access_modes=['ReadWriteMany']"
        ose3_vars << "openshift_hosted_registry_storage_volume_size=17G"

      end

      hosts.each do |role, role_hosts|
        role_hosts.each do |host|
          # upload to host with cat
          check_res \
            host.exec_admin('cat > configure_env.sh', stdin: conf_script)

          ## wait cloud-init setup to finish
          # TODO: http://stackoverflow.com/questions/33019093/how-do-detect-that-cloud-init-completed-initialization
          check_res host.exec_admin("sh configure_env.sh wait_cloud_init",
                                    timeout: 1800)

          if rhel_base_repo
            check_res host.exec_admin("sh configure_env.sh configure_repos")
          end
          if dns.start_with?("embedded_skydns")
            check_res host.exec_admin("sh configure_env.sh configure_hosts")
          end

          case role
          when "master"
            # TODO: assumption is only one master
            #if dns == "embedded"
            #  check_res host.exec_admin('sh configure_env.sh configure_dns')
            #elsif dns
            #  check_res \
            #    host.exec_admin('sh configure_env.sh configure_dns_resolution')
            #end

            if dns == "embedded_skydns"
              host_base_line = "#{host.ansible_host_str} openshift_hostname=master.#{host_domain} openshift_public_hostname=master.#{host_domain}"
            else
              host_base_line = "#{host.ansible_host_str} openshift_public_hostname=#{host.hostname}"
              if set_hostnames
                host_base_line << " openshift_hostname=#{host.hostname}"
              end
            end

            host_line = host_base_line.dup
            master_host_lines << host_line.dup

            host_line << " " << master_nodes_labels_str
            node_host_lines << host_line
          else
            if dns == "embedded_skydns"
              node_index = node_host_lines.size + 1
              host_base_line = "#{host.ansible_host_str} openshift_hostname=minion#{node_index}.#{host_domain} openshift_public_hostname=minion#{node_index}.#{host_domain}"
            else
              host_base_line = "#{host.ansible_host_str} openshift_public_hostname=#{host.hostname}"
              if set_hostnames
                host_base_line << " openshift_hostname=#{host.hostname}"
              end
            end
            host_line = %Q*#{host_base_line} openshift_node_labels="{'region': 'primary', 'zone': 'default'}"*
            node_host_lines << host_line

            #if dns
            #  check_res \
            #    host.exec_admin('sh configure_env.sh configure_dns_resolution')
            #end
          end

          # select etcd nodes
          if Integer(etcd_num) > etcd_host_lines.size
            etcd_host_lines << host_base_line
            # etcd_host_lines << host.hostname
          end

          # setup Load Balancer node(s); selected randomly before hosts loop
          if host == lb_node
            lb_host_lines << host_base_line
            ose3_vars << "openshift_master_cluster_public_hostname=#{host.hostname}"
            ose3_vars << "openshift_master_cluster_hostname=#{host.hostname}"
            ose3_vars << "openshift_master_cluster_method=native"
            #no need this line according to 1278706
            #ose3_vars << "openshift_master_ha=true"
          end
        end
      end

      ## load ansible inventory template with current binding
      hosts_str = ERB.new(File.read(hosts_erb)).result binding

      ## download ansible repo to workdir (need git pre-installed)
      Host.localhost.delete("openshift-ansible", :r => true)
      check_res Host.localhost.exec(
        "git clone #{ansible_url} openshift-ansible"
      )
      res = nil

      ## ssh-key param for ansible
      private_key_param = ""
      if ssh_key
        ssh_key_path = expand_private_path(ssh_key)
        File.chmod(0600, ssh_key_path)
        private_key_param = "--private-key #{Host.localhost.shell_escape(ssh_key_path)}"
      end

      # ansible goodies
      ENV["ANSIBLE_CALLBACK_WHITELIST"] = 'profile_tasks'
      ENV["ANSIBLE_FORCE_COLOR"] = "true"

      ## run pre-ansible hook (need ansible pre-installed)
      #  that basically means:
      #  * setup all needed repos
      #  * install git, ansible, docker, etc.
      #  * setup docker for any necessary repo auth
      #  * pull some images
      if pre_ansible && !pre_ansible.empty?
        prea_url = URI.parse pre_ansible
        prea_path = expand_private_path(prea_url.path, public_safe: true)
        prea_query = prea_url.query
        prea_params = prea_query ? CGI::parse(prea_query) : {}
        Collections.map_hash!(prea_params) { |k, v| [k, v.last] }
        prea_binding = Common::BaseHelper.binding_from_hash(binding, prea_params)
        eval(File.read(prea_path), prea_binding, prea_path)
      end

      ## finally run ansible
      Dir.chdir(Host.localhost.workdir) {
        logger.info("hosts file:\n" + hosts_str)
        File.write("hosts", hosts_str)
        # want to see output in real-time so Host#exec does not work
        # TODO: use new LocalHost exec functionality
        if use_rpm_playbook
          Host.localhost.exec('cat > configure_env.sh', stdin: conf_script)
          Host.localhost.exec_admin("sh configure_env.sh update_playbook_rpms")
          playbook_file = "/usr/share/ansible/openshift-ansible/playbooks/byo/config.yml"
        else
          playbook_file = "openshift-ansible/playbooks/byo/config.yml"
        end
        ansible_cmd = "ansible-playbook -i hosts #{private_key_param} -vvvv #{playbook_file}"
        logger.info("Running: #{ansible_cmd}")
        res = system(ansible_cmd)
      }
      case res
      when false
        raise "ansible failed with status: #{$?}"
      when nil
        raise "ansible failed to execute"
      end

      # check_res hosts['master'][0].exec_admin(
      #   "sh configure_env.sh replace_template_domain"
      # )

      ## setup SkyDNS for proper resolution (not supported)
      if dns == "embedded_skydns"
        check_res hosts['master'][0].exec_admin(
          "sh configure_env.sh add_skydns_hosts"
        )
      end

      ## setup Kerberos auth if requested
      if auth_type == "KERBEROS"
        check_res hosts['master'][0].exec_admin(
          'sh configure_env.sh confiugre_kerberos'
        )
      end

      ## setup testing image streams if requested
      modify_IS_for_testing = image_pre.partition("/")[0]
      if modify_IS_for_testing != "registry.access.redhat.com"
          check_res hosts['master'][0].exec_admin(
            "sh configure_env.sh modify_IS_for_testing #{modify_IS_for_testing}"
          )
      end
      
      ## create docker-registry if not use_nfs_storage
      if !use_nfs_storage
          check_res hosts['master'][0].exec_admin(
            "sh configure_env.sh create_router_registry"
          )
      end

      ## execute post-ansible hook
      # TODO
    ensure
      # Host clean_up
      if defined?(hosts) && hosts.kind_of?(Hash)
        hosts.each do |role, hosts|
          if hosts.kind_of? Array
            hosts.each do |host|
              if host.kind_of? Host
                host.clean_up
              end
            end
          end
        end
      end # Host clean_up
      Host.localhost.clean_up
    end

    # update launch options from ENV (used usually by jenkins jobs)
    # @param opts [Hash] instance launch opts to modify based on ENV
    # @return [Hash] the modified hash options
    def launcher_env_options(opts)
      if getenv("AUTH_TYPE") == "RANDOM"
        ## each day we want to use different auth type ignoring weekends
        time = Time.now
        day_of_year = time.yday
        passed_weeks_of_year = time.strftime('%W').to_i - 1
        opts[:auth_type] = ALTERNATING_AUTH[
          (day_of_year - 2 * passed_weeks_of_year) % ALTERNATING_AUTH.size
        ]
      elsif getenv("AUTH_TYPE")
        opts[:auth_type] = getenv("AUTH_TYPE")
      end

      # workaround https://issues.jenkins-ci.org/browse/JENKINS-30719
      # that means to remove extra `\` chars
      ENV['IMAGE_PRE'] = ENV['IMAGE_PRE'].gsub(/\\\${/,'${') if ENV['IMAGE_PRE']

      keys = [:crt_path, :deployment_type,
              :hosts_spec, :auth_type,
              :ssh_key, :ssh_user,
              :app_domain, :host_domain,
              :rhel_base_repo,
              :dns, :set_hostnames,
              :use_rpm_playbook,
              :use_nfs_storage,
              :image_pre,
              :puddle_repo,
              :etcd_num,
              :pre_ansible,
              :ansible_url,
              :customized_ansible_conf,
              :kerberos_docker_base_image,
              :kerberos_kdc, :kerberos_keytab_url,
              :kerberos_docker_base_image,
              :kerberos_admin_server]

      keys.each do |key|
        val = getenv(key.to_s.upcase)
        opts[key] = val if val
      end

      opts[:use_rpm_playbook] = false unless to_bool(opts[:use_rpm_playbook])
      opts[:use_nfs_storage] = false unless to_bool(opts[:use_nfs_storage])
    end

    # generate hostnames for any hosts that lack a real hostname or when forced
    # @param hosts_spec [Hash<String,Array<Host>>] this is
    #   {master => [host1, host2, ...], node => [host_n1, host_n2, ...]
    # @param mode [Symbol, String] :auto, false/nil, :force; when false we do not
    #   generate any hostnames, when auto we generate for hosts missing a hostname,
    #   and then forced we always generate a new hostname
    # @yield a block that will actually register hostnames and return FQDN
    # @yieldparam name [String] short desired hostname
    # @yieldparam ip [String] IP of the Host
    # @yieldreturn [String] FQDN of new hostname
    # @return undefined
    # @raise [StandardError] from yielded block
    def generate_hostnames(hosts_spec, mode)
      return unless mode
      hosts_spec.each do |type, hosts|
        hosts.each_with_index do |host, idx|
          if mode.to_s == "force" || !host.has_hostname?
            hostname = yield hosts.size > 1 ? "#{type}-#{idx+1}" : type, host.ip
            logger.info "Updated hostname of #{host.hostname} to #{hostname}"
            host.update_hostname(hostname)
          end
        end
      end
    end

    #def launch(**opts)
    #  # set OPENSTACK_SERVICE_NAME
    #  launch_os_instances(names:)
    #
    #  opts = launcher_env_options()
    #  ansible_install(**opts)
    #end

  end
end
