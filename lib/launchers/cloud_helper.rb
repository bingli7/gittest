# should not require 'common'
# should only include helpers that do NOT load any other cucushift classes

module CucuShift
  module Common
    module CloudHelper
      # based on information in https://github.com/openshift/vagrant-openshift/blob/master/lib/vagrant-openshift/templates/command/init-openshift/box_info.yaml
      # returns the proper username given the type of base image specified
      def get_username(image='rhel7')
        username = nil
        case image
        when 'rhel7', 'rhel7next'
          username = 'ec2-user'
        when 'centos7'
          username = 'centos'
        when 'fedora'
          username = 'fedora'
        when 'rhelatomic7'
          username = 'cloud-user'
        else
          raise "Unsupported image type #{image}"
        end
        return username
      end
    end
  end
end

