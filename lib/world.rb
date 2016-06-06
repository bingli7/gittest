require 'ostruct'
require 'common'
require 'collections'

require 'openshift/project'
require 'openshift/service'
require 'openshift/service_account'
require 'openshift/route'
require 'openshift/build'
require 'openshift/pod'
require 'openshift/persistent_volume'
require 'openshift/persistent_volume_claim'
require 'openshift/replication_controller'
require 'openshift/deployment_config'
module CucuShift
  # @note this is our default cucumber World extension implementation
  class DefaultWorld
    include CollectionsIncl
    include Common::Helper
    include Common::Hacks

    attr_accessor :scenario

    def initialize
      # we want to keep a reference to current World in the manager
      # hopefully cucumber does not instantiate us too early
      manager.world = self

      @clipboard = OpenStruct.new
      @browsers = []
      @bg_processes = []
      @bg_rulesresults = []
      # some arrays to store cached objects
      @projects = []
      @services = []
      @service_accounts = []
      @routes = []
      @builds = []
      @pods = []
      @pvs = []
      @pvcs = []
      @rcs = []
      @dcs = []
      @image_streams = []
      # used to store node the user wants to run commands on
      @host = nil

      # procs and lambdas to call on clean-up
      @teardown = []
    end

    # shorthand accessor for @clipboard
    def cb
      return @clipboard
    end

    def setup_logger
      CucuShift::Logger.runtime = @__cucumber_runtime
    end

    def debug_in_after_hook?
      scenario.failed? && conf[:debug_in_after_hook] || conf[:debug_in_after_hook_always]
    end

    def debug_in_after_hook
      if debug_in_after_hook?
        require 'pry'
        binding.pry
        fix_require_lock # see method in Common::Hacks
      end
    end

    def scenario_tags
      scenario.source_tag_names
    end

    def tagged_admin?
      scenario_tags.include? '@admin'
    end

    def tagged_destructive?
      scenario_tags.include? '@destructive'
    end

    def ensure_admin_tagged
      raise 'tag scenario @admin as you use admin access' unless tagged_admin?
    end

    def ensure_destructive_tagged
      raise 'tag scenario @admin and @destructive as you use admin access and failure to restore can have adverse effects to following scenarios' unless tagged_admin? && tagged_destructive?
    end

    # @note call like `user(0)` or simply `user` for current user
    def user(num=nil, switch: true)
      return @user if num.nil? && @user
      num = 0 unless num
      @user = env.users[num] if switch
      return env.users[num]
    end

    def service_account(name=nil, project: nil, project_name: nil, switch: true)
      return @service_accounts.last if name.nil? && !@service_accounts.empty?

      if project && project_name && project.name != project_name
        raise "project names inconsistent: #{project.name} vs #{project_name}"
      end
      project ||= self.project(project_name, generate: false)

      if name.nil?
        raise "requesting service account for the first time with no name"
      end

      sa = @service_accounts.find { |s|
        [ s.name, s.shortname ].include?(name) &&
        s.project == project
      }
      unless sa
        sa = ServiceAccount.new(name: name, project: project)
        @service_accounts << sa
      end
      @service_accounts << @service_accounts.delete(sa) if switch
      return sa
    end

    # @note call like `env(:key)` or simply `env` for current environment
    def env(key=nil)
      return @env if key.nil? && @env
      key ||= conf[:default_environment]
      raise "please specify default environment key in config or CUCUSHIFT_DEFAULT_ENVIRONMENT env variable" unless key
      return @env = manager.environments[key]
    end

    def admin
      env.admin
    end

    def host
      return @host
    end

    # @return project from cached projects for this scenario
    #   note that you need to have default `#env` set already;
    #   if no name is spefified, returns the last requested project;
    #   otherwise a CucuShift::Project object is created (but not created in
    #   the actual OpenShift environment)
    def project(name = nil, env: nil, generate: true, switch: true)
      env ||= self.env
      if name.kind_of? Integer
        p = @projects[name]
        raise "no project cached with index #{name}" unless p
        @projects << @projects.delete(p) if switch
        return p
      elsif name
        p = @projects.find {|p| p.name == name && p.env == env}
        if p && @projects.last.equal?(p)
          return p
        elsif p
          # put requested project at top of the stack
          @projects << @projects.delete(p) if switch
          return p
        else
          @projects << Project.new(name: name, env: env)
          return @projects.last
        end
      elsif @projects.empty?
        if generate
          @projects << Project.new(name: rand_str(5, :dns), env: env)
          return @projects.last
        else
          raise "no projects in cache"
        end
      else
        return @projects.last
      end
    end

    # @return service by name from scenario cache; with no params given,
    #   returns last requested service; otherwise creates a service object
    # @note you need the project already created
    def service(name = nil, project = nil)
      project ||= self.project

      if name
        s = @services.find {|s| s.name == name && s.project == project}
        if s && @services.last == s
          return s
        elsif s
          @services << @services.delete(s)
          return s
        else
          # create new CucuShift::Service object with specified name
          @services << Service.new(name: name, project: project)
          return @services.last
        end
      elsif @services.empty?
        # we do not create a random service like with projects because that
        #   would rarely make sense
        raise "what service are you talking about?"
      else
        return @services.last
      end
    end

    # @return PV by name from scenario cache; with no params given,
    #   returns last requested PV; otherwise creates a PV object
    def pv(name = nil, env = nil, switch: true)
      env ||= self.env

      if name
        pv = @pvs.find {|pv| pv.name == name && pv.env == env}
        if pv && @pvs.last == pv
          return pv
        elsif pv
          @pvs << @pvs.delete(s) if switch
          return pv
        else
          # create new CucuShift::PV object with specified name
          @pvs << PersistentVolume.new(name: name, env: env)
          return @pvs.last
        end
      elsif @pvs.empty?
        # we do not create a random PV like with projects because that
        #   would rarely make sense
        raise "what PersistentVolume are you talking about?"
      else
        return @pvs.last
      end
    end

    def route(name = nil, service = nil)
      service ||= self.service

      if name
        r = @routes.find {|r| r.name == name && r.service == service}
        if r && @routes.last == r
          return r
        elsif r
          @routes << @routes.delete(r)
          return r
        else
          # create new CucuShift::Route object with specified name
          @routes << CucuShift::Route.new(name: name, service: service)
          return @routes.last
        end
      elsif @routes.empty?
        # we do not create a random route like with projects because that
        #   would rarely make sense
        raise "what route are you talking about?"
      else
        return @routes.last
      end
    end

    # @return build by name from scenario cache; with no params given,
    #   returns last requested build; otherwise creates a [Build] object
    # @note you need the project already created
    def build(name = nil, project = nil)
      project ||= self.project(generate: false)

      if name
        b = @builds.find {|b| b.name == name && b.project == project}
        if b && @builds.last == b
          return b
        elsif b
          @builds << @builds.delete(b)
          return b
        else
          # create new CucuShift::Build object with specified name
          @builds << Build.new(name: name, project: project)
          return @builds.last
        end
      elsif @builds.empty?
        # we do not create a random build like with projects because that
        #   would rarely make sense
        raise "what build are you talking about?"
      else
        return @builds.last
      end
    end

    # @return rc (ReplicationController) by name from scenario cache;
    #   with no params given, returns last requested rc;
    #   otherwise creates a [ReplicationController] object
    # @note you need the project already created
    def rc(name = nil, project = nil)
      project ||= self.project(generate: false)

      if name
        r = @rcs.find {|r| r.name == name && r.project == project}
        if r && @rcs.last == r
          return r
        elsif r
          @rcs << @rcs.delete(r)
          return r
        else
          # create new CucuShift::ReplicationControler object with specified name
          @rcs << ReplicationController.new(name: name, project: project)
          return @rcs.last
        end
      elsif @rcs.empty?
        # we do not create a random build like with projects because that
        #   would rarely make sense
        raise "what rc are you talking about?"
      else
        return @rc.last
      end
    end

    # @return dc (DeploymentConfig) by name from scenario cache;
    #   with no params given, returns last requested dc;
    #   otherwise creates a [DeploymentConfig] object
    # @note you need the project already created
    def dc(name = nil, project = nil)
      project ||= self.project(generate: false)

      if name
        dc = @dcs.find {|d| d.name == name && d.project == project}
        if dc && @dcs.last == dc
          return dc
        elsif dc
          @dcs << @dcs.delete(dc)
          return dc
        else
          # create new CucuShift::DeploymentConfig object with specified name
          @dcs << DeploymentConfig.new(name: name, project: project)
          return @dcs.last
        end
      elsif @dcs.empty?
        # we do not create a random build like with projects because that
        #   would rarely make sense
        raise "what dc are you talking about?"
      else
        return @dc.last
      end
    end

    # @return [ImageStream] is by name from scenario cache; with no params given,
    #   returns last requested is; otherwise creates an [ImageStream] object
    # @note you need the project already created
    def image_stream(name = nil, project = nil)
      project ||= self.project(generate: false)

      if name
        is = @image_streams.find {|s| s.name == name && s.project == project}
        if is && @image_streams.last == is
          return is
        elsif is
          @image_streams << @image_streams.delete(is)
          return is
        else
          # create new CucuShift::Build object with specified name
          @image_streams << ImageStream.new(name: name, project: project)
          return @image_streams.last
        end
      elsif @image_streams.empty?
        # we do not create a random is like with projects because that
        #   would rarely make sense
        raise "what is are you talking about?"
      else
        return @image_streams.last
      end
    end

    # @return [PersistentVolumeClaim] last used PVC from scenario cache;
    #   with no params given, returns last requested is;
    #   otherwise creates an [PersistentVolumeClaim] object with the given name
    # @note you need the project already created
    def pvc(name = nil, project = nil)
      project ||= self.project(generate: false)

      if name
        pvc = @pvcs.find {|s| s.name == name && s.project == project}
        if pvc && @pvcs.last == pvc
          return pvc
        elsif pvc
          @pvcs << @pvcs.delete(pvc)
          return pvc
        else
          # create new object with specified name
          @pvcs << PersistentVolumeClaim.new(name: name, project: project)
          return @pvcs.last
        end
      elsif @pvcs.empty?
        # we do not create a random pvc like with projects because that
        #   would rarely make sense
        raise "what PVC are you talking about?"
      else
        return @pvcs.last
      end
    end

    # @return web4cucumber object from scenario cache
    def browser(num = -1)
      num = Integer(num) rescue word_to_num(num)

      raise "no web browsers cached in World" if @browsers.empty?

      case
      when num > @browsers.size + 1 || num < -@browsers.size
        raise "web browsers index not found: #{num} for size #{@browsers.size}"
      else
        cache_browser(@browsers[num]) unless num == -1
        return @browsers.last
      end
    end

    # put the specified browser at top of our cache avoiding duplicates
    def cache_browser(browser)
      @browsers.delete(browser)
      @browsers << browser
    end

    # @return pod by name from scenario cache; with no params given,
    #   returns last requested pod; otherwise creates a [Pod] object
    # @note you need the project already created
    def pod(name = nil, project = nil)
      project ||= self.project

      if Integer === name
        return @pods[name] || raise("no pod with index #{name}")
      elsif name
        p = @pods.find {|p| p.name == name && p.project == project}
        if p && @pods.last == p
          return p
        elsif p
          @pods << @pods.delete(p)
          return p
        else
          # create new CucuShift::Pod object with specified name
          @pods << Pod.new(name: name, project: project)
          return @pods.last
        end
      elsif @pods.empty?
        # we do not create a random pod like with projects because that
        #   would rarely make sense
        raise "what pod are you talking about?"
      else
        return @pods.last
      end
    end

    # add pods to list avoiding duplicates
    def cache_pods(*new_pods)
      new_pods.each {|p| @pods.delete(p); @pods << p}
    end

    # @param procs [Proc] a proc or lambda to add to teardown
    # @yield [] a block that will be added to teardown
    # @note teardowns should ever raise only if issue can break further
    #   scenario execution. When a teardown raises, that causes cucumber to
    #   skip executing any further scenarios.
    def teardown_add(*procs, &block)
      @teardown.concat procs
      if block
        @teardown << block
      end
    end

    def quit_cucumber
      Cucumber.wants_to_quit = true
    end

    def after_scenario
      # call all teardown lambdas and procs; see [#teardown_add]
      # run last registered teardown routines first
      @teardown.reverse_each { |f| f.call }
    end

    def hook_error!(err)
      if err
        quit_cucumber
        raise err
      end
    end
  end
end
