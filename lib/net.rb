require 'socket'

module CucuShift
  module Common
    module Net
      # @return single DNS entry for a hostname
      def self.dns_lookup(hostname, af: Socket::AF_INET, multi: false)
        res = Socket.getaddrinfo(hostname, 0, af, Socket::SOCK_STREAM, nil, Socket::AI_CANONNAME)

        if res.size < 1
          raise "cannot resolve hostname: #{hostname}"
        end

        return multi ? res.map{|r| r[3]} : res[0][3]
      end

      def self.reverse_lookup(ip)
        res = Socket.getaddrinfo(ip, 0, Socket::AF_UNSPEC, Socket::SOCK_STREAM, nil, Socket::AI_CANONNAME, true)

        if res.size != 1
          raise "not sure how to handle multiple entries, please report to author"
        end

        return res[0][2] # btw this might be same IP if reverse entry missing
      end
    end
  end
end
