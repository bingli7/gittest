require 'cgi'
require 'uri'

require 'http'

module CucuShift
  # represents an OpenShift token
  class Token
    include Common::Helper

    attr_reader :user, :token, :valid_until

    # @param [CucuShift::User] user the user owning the token
    # @param [String] token the actual token string
    # @param [Time] valid the time until token is valid
    def initialize(user:, token:, valid:)
      if ! token || token.empty?
        raise 'new token string should not be nil, false or empty'
      end

      @user = user
      @token = token.to_s.freeze
      @valid_until = valid

      # in some environments we can't obtain tokens dynamically
      # lets make sure we do not revoke/delete these tokens
      @protected = false
    end

    def protected?
      @protected
    end
    def protect
      @protected = true
      return self
    end

    # it token still valid? 10 seconds given to avoid misleading result due to
    #   network delays
    def valid?(grace_period: 10)
      valid_until > Time.now + grace_period
    end

    # @param [Boolean] uncache remove token from user object cache regardless of
    #   success
    def delete(uncache: false)
      if protected?
        res = { success: false, instruction: "delete token #{token}",
                exitstatus: 1, response: "should not remove protected tokens"
        }
      else
        res = user.rest_request(:delete_oauthaccesstoken, token_to_delete:token)
      end

      if res[:success] || uncache
        user.cached_tokens.delete(self)
      end

      return res
    end

    # @param [CucuShift::User] user the user we want token for
    # @return [CucuShift::Token]
    def self.new_oauth_bearer_token(user)
      res = oauth_bearer_token_challenge(
        server_url: user.env.api_endpoint_url,
        user: user.name,
        password: user.password
      )

      unless res[:success]
        msg = "Error getting bearer token, see log"
        if res[:error]
          raise res[:error] rescue raise msg rescue e=$!
        else
          raise msg rescue e=$!
        end
        Http.logger.error(e) # default error printing exclude cause
        raise e
      end

      t = Token.new(user: user, token: res[:token], valid: res[:valid_until])
      user.cached_tokens << t
      return t
    end


    # @param [String] server_url e.g. "https://master.cluster.local:8443"
    # @param [String] user the username to get a token for
    # @param [String] password
    # @return [CucuShift::ResultHash]
    # @note curl -u joe -kv -H "X-CSRF-Token: xxx" 'https://master.cluster.local:8443/oauth/authorize?client_id=openshift-challenging-client&response_type=token'
    def self.oauth_bearer_token_challenge(server_url:, user:, password:)
      # :headers => {'X-CSRF-Token' => 'xx'} seems not needed
      opts = {:user=> user,
              :password=> password,
              :max_redirects=>0,
              :url=>"#{server_url}/oauth/authorize",
              :params=> {"client_id"=>"openshift-challenging-client", "response_type"=>"token"},
              :method=>"GET"
      }
      res = Http.request(**opts)

      if res[:exitstatus] == 302 && res[:headers]["location"]
        begin
          uri = URI.parse(res[:headers]["location"][0])
          params = CGI::parse(uri.fragment)
          res[:token] = params["access_token"][0]
          res[:expires_in] = params["expires_in"][0]
          res[:valid_until] = Time.new + Integer(res[:expires_in])
          res[:success] = true
        rescue => e
          res[:error] = e
        end
      end

      return res
    end
  end
end
