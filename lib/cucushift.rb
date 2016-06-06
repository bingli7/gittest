require 'etc'
require 'socket'
# should not require 'common' and any other files from cucushift, base helpers
#   are fine though

# @note put only very base things here, do not use for configuration settings
module CucuShift
  # autoload to avoid too much require statements and speed-up load times
  autoload :Dynect, 'launchers/dyn/dynect'
  autoload :Amz_EC2, 'launchers/amz'
  autoload :GCE, 'launchers/gce'
  autoload :OpenStack, "launchers/openstack"
  autoload :EnvironmentLauncher, "launchers/environment_launcher"
  autoload :LocalProcess, "local_process.rb"

  autoload :ImageStream, "openshift/image_stream"
  autoload :Project, "openshift/project"

  HOME = File.expand_path(__FILE__ + "/../..")
  PRIVATE_DIR = ENV['CUCUSHIFT_PRIVATE_DIR'] || File.expand_path(HOME + "/private")
  HOSTNAME = Socket.gethostname.freeze
  LOCAL_USER = Etc.getlogin.freeze

  GIT_HASH = `git rev-parse HEAD --git-dir="#{File.join(HOME,'.git')}"`.
                lines[0].chomp rescue :unknown
  GIT_PRIVATE_HASH =
    `git rev-parse HEAD --git-dir="#{File.join(PRIVATE_DIR,'.git')}"`.
      lines[0].chomp rescue :unknown

  if ENV["NODE_NAME"]
    # likely a jenkins environment
    EXECUTOR_NAME = "#{ENV["NODE_NAME"]}-#{ENV["EXECUTOR_NUMBER"]}".freeze
  else
    EXECUTOR_NAME = "#{HOSTNAME.split('.')[0]}-#{LOCAL_USER}".freeze
  end

  START_TIME = Time.now
  TIME_SUFFIX = [
    START_TIME.strftime("%Y"),
    START_TIME.strftime("%m"),
    START_TIME.strftime("%d"),
    START_TIME.strftime("%H:%M:%S")
  ]
end
