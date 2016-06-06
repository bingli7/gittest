
module CucuShift
  # just a placeholder to define what a result hash means
  #   A ResultHash should contain at least the following keys:
  #   * :success       # true/false value showing if operation succeeded
  #   * :instruction   # human readable shor description of instruction issued
  #   * :response      # output from command or server response
  #   * :exitstatus    # numeric exit status from operation
  #   Some optional keys:
  #   * props          # some optional properties obtained from the operation
  #   * error          # error that caused operation failure
  class ResultHash < Hash
  end
end
