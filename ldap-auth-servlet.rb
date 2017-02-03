#!/usr/bin/env ruby

### Ruby LDAP authentication servlet for nginx HTTP auth request module ###

# Purpose: This simple Ruby script implements a WEBrick HTTPS servlet listening by default on port 8888 in order to authenticate against an LDAP server using STARTTLS and thus enabling you to provide LDAP authentication for your nginx website.

require 'webrick'
require 'webrick/https'
require 'base64'
require 'net/ldap'
require 'yaml'

# Path to config file and default configuration parameters
config_file = File.join(__dir__, 'config.yaml')
config = {}
config['daemonize'] = false
config['http_auth_realm'] = 'Ruby LDAP authentication servlet'
config['ldap_host'] = 'localhost'
config['ldap_port'] = 389
config['ldap_auth_attribute'] = 'uid'
config['ldap_auth_base_dn'] = 'ou=people,dc=domain,dc=tld'
config['servlet_port'] = 8888
config['servlet_ssl_certificate_cn'] = 'localhost'

class LDAPAuthServlet < WEBrick::HTTPServlet::AbstractServlet
	def initialize server, config
		super server
		@config = config
	end

    def do_GET (request, response)
		# Check for authorization HTTP header to perform authentication
		if request.header.include?('authorization')
			http_auth_header = request.header['authorization']

			# Extract basic auth string
	 		auth_encoded = http_auth_header[0].split(' ').last

	 		# Decode basic auth string
			auth_decoded = Base64.decode64(auth_encoded)

			# Split auth string into an array with username and password
			credentials = auth_decoded.split(':')

			# Check for empty credentials, empty password or empty username
			unless credentials.empty? or credentials.count == 1 or credentials[0].to_s.strip.length == 0
				# Define LDAP connection using STARTTLS for encryption
				ldap = Net::LDAP.new(:encryption => { :method => :start_tls })  
				ldap.host = @config['ldap_host']
				ldap.port = @config['ldap_port']

				# Generate bind DN using passed username
				bind_dn = @config['ldap_auth_attribute']+'='+credentials[0].strip+','+@config['ldap_auth_base_dn']
				
				# Authenticate with LDAP server
				ldap.auth bind_dn, credentials[1].strip

				# Catch errors such as Errno::ECONNREFUSED
				begin
					# Check for succesfull authentication
					if ldap.bind
						# Return HTTP OK on successful auth
						puts '[INFO]: Authentication succesful for user '+credentials[0]
						response.status = 200
						# Avoid ERR_SSL_SERVER_CERT_BAD_FORMAT from Chrome
#						response.header['Content-Type'] = 'text/plain'
#						response.body = 'OK'
						return
					else
						# HTTP Unauthorized on failed auth
						puts '[INFO]: Authentication failed for user '+credentials[0]
					end
				rescue => e
					$stderr.puts '[ERROR]: Class -> '+e.class.to_s
					$stderr.puts '[ERROR]: Message -> '+e.message
					$stderr.puts '[ERROR]: LDAP result object -> '+ldap.get_operation_result.to_s
					$stderr.puts '[ERROR]: LDAP result message -> '+ldap.get_operation_result.message
				end
			end
		else
			# First HTTP authentication attempt
			puts '[INFO]: Authentication started'
		end
		# Default behaviour is to return HTTP Unauthorized
		response.status = 401
		response.header['Cache-control'] = 'no-cache'
		response.header['WWW-Authenticate'] = 'Basic realm="'+@config['http_auth_realm']+'"'
    end
end

puts "\n### Ruby LDAP authentication servlet for nginx HTTP auth request module ###\n\n"

if File.exist?(config_file)
	puts '[INFO]: Config file config.yaml found, using this file for configuration parameters.'
	config = YAML::load_file(config_file)
else
	puts '[WARNING]: Config file config.yaml does not exist, using default configuration parameters.'
end

# Setup WEBrick with servlet
cert_name = [['CN', config['servlet_ssl_certificate_cn']]]
server = WEBrick::HTTPServer.new(:Port => config['servlet_port'], :SSLEnable => true, :SSLCertName => cert_name)
server.mount '/', LDAPAuthServlet, config

# Start WEBrick as daemon in background
if config['daemonize'] == true
	WEBrick::Daemon.start
end

trap('INT') {
	  server.shutdown
}

server.start