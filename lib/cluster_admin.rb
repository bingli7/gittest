module CucuShift
  # small abstraction over having admin access to environment
  class ClusterAdmin
    attr_reader :env

    def initialize(env:)
      @env = env
    end

    # just blindly delegates to Environment#admin_cli_executor
    def cli_exec(*args, &block)
      env.admin_cli_executor.exec(*args, &block)
    end
  end
end
