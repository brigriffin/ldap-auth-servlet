# Ruby LDAP authentication servlet for nginx HTTP auth request module

nginx does not offer HTTP authentication using LDAP (or any other type of databases) as backend out of the box. Fortunately nginx features a module named ngx_http_auth_request_module which enables client authorization based on the result of an HTTP/HTTPS subrequest. Using this module in combination with the nginx HTTP proxy module it is possible to authenticate against any web service returning either an HTTP 200 code on authentication success or HTTP 401 code on authentication failure.

This simple Ruby script implements a WEBrick HTTPS servlet listening by default on port 8888 in order to authenticate against an LDAP server using STARTTLS and thus enabling you to provide LDAP authentication for your nginx website.

## Installation

You will need Ruby and the bundler gem in order to install and run this script. Read below for the installation instructions.

### Install bunlder

	$ gem install bundler

### Install dependencies
Currently the only required gem is net-ldap.

	$ bundle

### Configure the script

Copy the sample `config.sample.yaml` file as `config.yaml` and adapt it for your LDAP environment.

### Configure nginx

1. Add to your nginx http configuration (e.g. `/etc/nginx/conf.d/auth_cache.conf`):

	```
	proxy_cache_path cache/ keys_zone=auth_cache:5m;
	```

	The credentials are cached for 5 minutes, feel free to increase or decrease. If you change this parameter do not forget to also adapt `proxy_cache_valid` under point 2. below.

2. Add to your nginx server configuration (e.g. `/etc/nginx/conf.d/mywebsite.ch`):

	```
	satisfy any;
	auth_basic "Ruby LDAP authentication servlet";
	auth_basic_user_file "/etc/nginx/empty.htpasswd";
	auth_request /auth;

	location = /auth {
		proxy_pass https://localhost:8888;
		proxy_cache auth_cache;
		proxy_cache_valid 200 5m;
		proxy_pass_request_body off;
		proxy_set_header Content-Length "";
		proxy_set_header X-Original-URI $request_uri;
	}
	```

	This will protect the whole website. It is also possible to protect parts of it by including the first block in an nginx specific location such as `/private`:

	```
	location /private {
		satisfy any;
		auth_basic "Ruby LDAP authentication servlet";
		auth_basic_user_file "/etc/nginx/empty.htpasswd";
		auth_request /auth;
	}
	```

3. Create an empty htpasswd file

	This is required and I did not find any way around it.

		$ touch /etc/nginx/empty.htpasswd

4. Reload nginx

		$ systemctl reload nginx

### Start the script

	$ ./ldap-auth-servlet.rb

Once you have tested that everything works well it is recommended to run the script in background in daemon mode by changing the `daemonize` parameter in the `config.yaml` file to `true`.

## Tested with

This script has been tested with the following setup:

- Debian 8
- Ruby 2.4.0
- nginx 1.6.2
- OpenLDAP 2.4

## TODO

- Support multiple LDAP servers