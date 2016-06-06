require_relative 'oo_exception'
require_relative 'dynect_plugin'

module CucuShift
  # we reuse DynectPlugin and add our convenience methods
  class Dynect < ::OpenShift::DynectPlugin
    # FYI logger method is overridden by Helper so we should be good to go
    include Common::Helper
    extend Common::BaseHelper

    def initialize(opts={})
      args = opts.dup
      args.merge! conf[:services, :dyndns]
      args.merge! get_env_credentials
      unless args[:user_name] && args[:password]
        raise "no Dynect credentials found"
      end
      super(args)
    end

    def get_env_credentials
      idx = ENV["DYNECT_CREDENTIALS"].index(':')
      if idx
        return { user_name: ENV["DYNECT_CREDENTIALS"][0..idx-1],
                 password: ENV["DYNECT_CREDENTIALS"][idx+1..-1]}
      else
        return {}
      end
    end

    def dyn_get(path, auth_token=@auth_token, retries=@@dyn_retries)
      headers = { "Content-Type" => 'application/json', 'Auth-Token' => auth_token }
      url = URI.parse("#{@end_point}/REST/#{path}")
      resp, data = nil, nil
      dyn_do('dyn_get', retries) do
        http = Net::HTTP.new(url.host, url.port)
        # below line get rid of the warning message
        # warning: peer certificate won't be verified in this SSL session
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        #http.set_debug_output $stderr
        http.use_ssl = true
        begin
          logheaders = headers.clone
          logheaders["Auth-Token"]="[hidden]"
          logger.debug "DYNECT has? with path: #{url.path} and headers: #{logheaders.inspect}"
          resp = http.get(url.path, headers)
          data = resp.body
          case resp
          when Net::HTTPSuccess
           if data
             data = JSON.parse(data)
             if data['status'] == 'success'
               logger.debug "DYNECT Response data: #{data['data']}"
             else
               logger.debug "DYNECT Response status: #{data['status']}"
               raise_dns_exception(nil, resp)
             end
           end
          when Net::HTTPNotFound
            logger.error "DYNECT returned 404 for: #{url.path}"
          when Net::HTTPTemporaryRedirect
            resp, data = handle_temp_redirect(resp, auth_token, 100)
          else
            raise_dns_exception(nil, resp)
          end
        rescue OpenShift::DNSException => e
          raise e
        rescue Exception => e
          raise_dns_exception(e)
        end
      end
      return resp, data
    end

    def dyn_create_a_records(record, target, auth_token=@auth_token, retries=@@dyn_retries)
      fqdn = record.end_with?('.') ? record[0..-2] : "#{record}.#{@domain_suffix}"
      path = "ARecord/#{@zone}/#{fqdn}/"
      # Create the A records
      [target].flatten.each { |target|
        logger.info "Configuring '#{fqdn}' A record to '#{target}'"
        record_data = { :rdata => { :address => target }, :ttl => "60" }
        dyn_post(path, record_data, auth_token, retries)
      }
      return fqdn
    end
    alias dyn_create_a_record dyn_create_a_records

    # @return [String] random `timed` FQDN
    def dyn_create_random_a_wildcard_records(target, auth_token=@auth_token, retries=@@dyn_retries)
      record = "*.#{gen_timed_random_component}"
      return dyn_create_a_records(record, target, auth_token, retries)
    end
    alias dyn_create_random_a_wildcard_record dyn_create_random_a_wildcard_records

    def dyn_get_all_zone_records(auth_token=@auth_token, retries=@@dyn_retries)
      resp, data = dyn_get("AllRecord/#{@zone}", auth_token, retries)
      return data["data"]
    end

    def self.gen_timed_random_component
      return Time.now.strftime("%m%d") << "-" << rand_str(3, :dns)
    end

    def gen_timed_random_component
      self.class.gen_timed_random_component
    end

    # @return [Time]
    def time_from_tstamp(tstamp, now = nil)
      now ||= Time.now
      year = now.year
      month = tstamp[0..1].to_i
      day = tstamp[2..-1].to_i
      time = Time.mktime(year, month, day)
      if time > now
        # seems like record from previous year
        time = Time.mktime(year - 1, month, day)
      end
      return time
    end

    # @return [Array] of name, [Time], record_api_path
    def dyn_get_timed_a_records(auth_token=@auth_token, retries=@@dyn_retries)
      expr = %r%^/REST/ARecord/([^/]*)/((?:[^.][.])?([0-9]{4})-[^.]+[.]\1)/%
      all = dyn_get_all_zone_records(auth_token, retries)
      now = Time.now
      res = []
      all.each { |rec|
        m = rec.match expr
        if m
          name = m[2]
          tstamp = time_from_tstamp(m[3], now)
          record_api_path = rec.sub(%r%^/REST/%, "")
          res << [name, tstamp, record_api_path]
        end
      }
      return res
    end

    # @param time [Time] the time records should be older than
    # @param records [Array] of name, [Time], record_api_path
    # @return [Array] of name, [Time], record_api_path (of older records)
    def records_older_than(time, records)
      records.select { |r|
        r[1] < time
      }
    end

    # @param records [Array<String>] api records paths
    def dyn_delete_records(records, auth_token=@auth_token, retries=@@dyn_retries)
      records.each { |r|
        path = r.sub(%r%^/REST/%, '')
        dyn_delete(path, auth_token, retries)
      }
    end

    # @param time [Time] the time records should be older than
    # @return [Array<String>] records that have been removed
    def delete_older_timed_records(time, auth_token=@auth_token, retries=@@dyn_retries)
      records = dyn_get_timed_a_records(auth_token, retries)
      older = records_older_than(time, records).map { |r| r[2] }
      dyn_delete_records(older, auth_token, retries)
      return older
    end
  end
end
