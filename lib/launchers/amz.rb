#!/usr/bin/env ruby
require 'aws-sdk'

require 'common'
require 'host'
require 'launchers/cloud_helper'

module CucuShift

  class Amz_EC2
    include Common::Helper
    include Common::CloudHelper

    attr_reader :config

    def initialize
      @config = conf[:services, :AWS]

      awscred = nil
      # try to find a suitable Amazon AWS credentials file
      [ expand_private_path(config[:awscred]),
      ].each do |cred_file|
        begin
          cred_file = File.expand_path(cred_file)
          logger.info("Using #{cred_file} credentials file.")
          awscred = Hash[File.read(cred_file).scan(/(.+?)=(.+)/)]
          break # break if no error was raised above
        rescue
          logger.warn("Problem reading credential file #{cred_file}")
          next # try next configuration file
        end
      end

      raise "no readable credentials file found" unless awscred
      Aws.config.update( config[:config_opts].merge({
        credentials: Aws::Credentials.new(
          awscred["AWSAccessKeyId"],
          awscred["AWSSecretKey"]
        )
      }) )
      client = Aws::EC2::Client.new
      @ec2 = Aws::EC2::Resource.new(client: client)
    end

    def create_instance(image_id=nil)
      launch_instances(image=image_id)
    end

    ########################################################################
    # AMI helper methods
    ########################################################################
    def get_amis(filter_val=config[:ami_types][:devenv_wildcard])
      # returns a list of amis
       @ec2.images({
        filters: [
            {
              name: "name",
              values: [filter_val],
            },
            {
              name: "state",
              values: ["available"],
            },
          ],
       }).to_a
    end

    def get_all_qe_ready_amis()
      # returns a list of amis
       @ec2.images({
        filters: [
            {
              name: "state",
              values: ["available"],
            },
            {
              name: "tag-value",
              values: [config[:tag_ready]],
            },
          ],
        })

    end
    # Returns the ami-id given a name
    # @return [Sting] ami-id, if no match then nil
    #
    def get_ami_id_from_name(ami_name)
      ami = @ec2.images({
        filters: [
            {
              name: "name",
              values: [ami_name],
            },
          ],
        }).to_a
      if ami.count == 0
        return nil
      else
        return ami[0].id
      end
    end

    def filter_available_amis(*filters)
      filters << {
        name: "state",
        values: ["available"]
      }
      return @ec2.images({ filters: filters })
    end

    def filter_qe_ready_amis(*filters)
      filters << {
        name: "tag-value",
        values: [config[:tag_ready]]
      }
      return filter_available_amis(*filters)
    end

    def get_latest_ami(filter_val = nil)
      v3_types = [:fedora, :centos7, :rhel7, :rhel7next]
      case filter_val
      when nil
        # latest devenv regardless of OS
        filter_val = v3_types.map { |t| filter_val=config[:ami_types][t] }
      when Array
        # do nothing
      when String
        filter_val = filter_val.split(",")
      else
        raise "dunno what this filter is: #{filter_val.inspect}"
      end

      amis = filter_qe_ready_amis({name: "name", values: filter_val}).to_a
      if amis.empty?
        logger.warn("no qe-ready AMIs found, trying non-ready with names: #{filter_val}")
        amis = filter_available_amis({name: "name", values: filter_val})
      end

      # take latest ami by date
      img = amis.sort_by {|ami| ami.creation_date}.last
      unless img
        raise "could not find specified image: #{filter_val}"
      end
      return img
    end

    # TODO: convert to v2 AWS API
    # Returns snaphost hash
    # @return [Hash] snapshot_set
    # example: {:tag_set=>[], :snapshot_id=>"snap-b4f04508", :volume_id=>"vol-81ab9fce", :status=>"completed", :start_time=>2014-11-11 16:05:50 UTC, :progress=>"100%", :owner_id=>"531415883065", :volume_size=>25, :description=>"Created by CreateImage(i-37f49418) for ami-1e51db76 from vol-81ab9fce", :encrypted=>false}
    # def get_snapshot_info(ami_id)
    #   client = @ec2.client
    #   res = @ec2.client.describe_images({:image_ids => [ami_id]})
    #   begin
    #     snapshot_id = res.images_set[0].block_device_mapping[0].ebs.snapshot_id
    #     snapshot_res = client.describe_snapshots({:snapshot_ids=> [snapshot_id]})
    #     return snapshot_res.snapshot_set[0]
    #   rescue
    #     $logger.info("Unable to get ami creation time for #{ami_id}, will be not stored into database")
    #     return nil
    #   end
    # end

    # Returns latest devenv_* AMI
    # @return [String] ami-id
    def get_latest_v2_ami
      return get_latest_ami(config[:ami_types][:devenv_v2])
    end

    # Returns latest devenv-stage_* AMI
    # @return [String] ami-id
    def get_latest_stable_v2_ami
      return get_latest_ami(config[:ami_types][:devenv_stable_v2])
    end

    # @param [String] ec2_tag the EC2 'Name' tag value
    # @return [Array<String>, Array<Object>] the array of IP address with array of instances object
    #
    def get_instance_ip_by_tag(ec2_tag)
      instances = @ec2.instances({
        filters: [
          {
            name: "tag:Name",
            values:[ec2_tag],
          },
        ]
      }).to_a
      if block_given?
        instances.each do |i|
          yield(i)
        end
      else
        ips = instances.map { |i| i.public_dns_name }
        return ips, instances
      end
    end

    #
    # @return [Array<Object>]
    def get_instance_by_id(ec2_instance_id)
      return @ec2.instances({
        filters: [
          {
            name: "instance-id",
            values:[ec2_instance_id],
          },
        ]
      }).to_a[0]
    end

    def get_instance_by_ip(ec2_instance_ip)
      # convert dns name to IP if necessary
      require 'resolv'
      ec2_instance_ip = Resolv.getaddress(ec2_instance_ip) unless ec2_instance_ip =~ /^[0-9]/
      res = @ec2.instances({
        filters: [
          {
            name: "ip-address",
            values:[ec2_instance_ip],
          },
        ]
      }).to_a[0]
    end
    # @param [String] ami_id the EC2 AMI-ID
    # @return [Array<String>, Array<Object>] the array of IP address with array of instances object
    #
    def get_instance_ip_by_ami_id(ami_id)
      instances = @ec2.instances({
        filters: [
          {
            name: "image-id",
            values:[ami_id],
          },
        ]
      }).to_a
      ips = instances.map{ |i| i.public_dns_name }
      return ips, instances
    end

    def add_name_tag(instance, name, retries=2)
      retries.times do |i|
        begin
          # tag the instance
          return instance.create_tags({
            tags: [
              {
                key: "Name",
                value: name,
              },
            ]
            })
        rescue Exception => e
          logger.info("Failed adding tag: #{e.inspect}")
          if i >= retries - 1
            raise "could not add name tag after #{retries} attempts"
          end
          sleep 5
        end
      end
      raise "should never be here"
    end

    def instance_status(instance)
      10.times do |i|
        begin
          status = instance.state[:name].to_sym
          return status
        rescue Exception => e
          if i >= 10 - 1
            raise "Failed to get instance status after 10 retries: #{e.inspect}"
          end
          logger.info("Error getting status(retrying): #{e.inspect}")
          sleep 30
        end
      end
      raise "should never be here"
    end

    # returns ssh connection
    def get_host(instance, host_opts={}, wait: false)
      host_opts = config[:host_opts].merge host_opts
      host_opts[:cloud_instance] = instance
      host_opts[:cloud_instance_name] = instance.tags.find{|t| t[:key] == "Name"}[:value]
      if instance.public_dns_name == ''
        logger.info("Reloading instance...")
        instance.reload
      end

      hostname = instance.public_dns_name
      host = CucuShift.const_get(config[:hosts_type]).new(hostname, host_opts)
      if wait
        logger.info("Waiting for #{hostname} to become accessible..")
        res = host.wait_to_become_accessible(600)

        unless res[:success]
          terminate_instance(instance)
          logger.error res[:response]
          # raise error with a cause (ever heard of that ruby dude?)
          raise res[:error] rescue
                raise ScriptError, "SSH availability timed out for #{hostname}"
        end
        logger.info "Instance (#{hostname}) is accessible"
      else
        logger.info("hostname: #{hostname}")
      end
      return host
    end

    def terminate_instance(instance)
      # we don't really have root permission to terminate, we'll just label it
      # 'teminate-qe' and let charlie takes care of it.
      logger.info("Terminating instance #{instance.public_dns_name}")
      instance.stop
      add_name_tag(instance, 'terminate-qe')
    end

    # Launch an EC2 instance either based on particular AMI or with the latest one.
    # If a tag_name is given then launch instance with it, otherwise use
    # the naming convention of QE_devenv_<latest_ami>
    #
    # @param [String] image the AMI id or filter type (e.g. rhel7, stage, etc.)
    # @param [Array, String] tag_name the tag name(s) for EC2 instance(s);
    #   is Array, it overrides min/max count with the number of elements
    # @param [Hash] create_opts for EC2, see
    #   http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Resource.html#create_instances-instance_method
    # @param [Integer] max_retries max retries to try (TODO)
    #
    # @return [Array] of [amz_instance, CucuShift::Host] pairs
    #
    def launch_instances(image: nil,
                         tag_name: nil,
                         create_opts: nil,
                         max_retries: 1,
                         wait_accessible: false)
      # default to use rhel if no filter is specified
      instance_opt = config[:create_opts] ? config[:create_opts].dup : {}
      instance_opt.merge!(create_opts) if create_opts

      if image.kind_of? Symbol
        image = config[:ami_types][image]
      end

      case image
      when Aws::EC2::Image
        instance_opt[:image_id] = image.id
      when nil
        unless instance_opt[:image_id]
          image = get_latest_ami
          instance_opt[:image_id] = image.id
        end
      when /^ami-.+/
        instance_opt[:image_id] = image
        # image = @ec2.images[image]
      else
        logger.info("Using image filter #{image}...")
        image = self.get_latest_ami(image)
        instance_opt[:image_id] = image.id
      end

      case tag_name
      when nil
        unless image.kind_of? Aws::EC2::Image
          image = @ec2.images[instance_opt[:image_id]]
        end
        tag_name = [ "QE_" + image.name + "_" + rand_str(4) ]
      when String
        tag_name = [ tag_name ]
      when Array
        instance_opt[:min_count] = instance_opt[:max_count] = tag_name.size
      end

      logger.info("Launching EC2 instance from #{image.kind_of?(Aws::EC2::Image) ? image.name : image.inspect} with tags #{tag_name}...")
      instances = @ec2.create_instances(instance_opt)

      res = []
      instances.each_with_index do | instance, i |
        tag = tag_name[i] || tag.last
        inst = instance.wait_until_running
        logger.info("Tagging instance with name #{tag} ...")
        tag_hash = {key: "Name", value: tag}
        inst.create_tags({ tags: [ tag_hash ] })
        inst.tags << tag_hash # odd that we need this
        # make sure we can ssh into the instance
        host = get_host(inst, wait: wait_accessible)
        res << [inst, host]
      end
      return res
    end
  end
end
