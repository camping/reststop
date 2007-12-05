require 'net/http'
require 'uri'
require 'cgi'

begin
  require 'xml_simple'
rescue LoadError
  require 'rubygems'
  require 'active_support'
  require 'xml_simple'
end


# A very simple REST client, best explained by example:
#
#   # Retrieve a Kitten
#   kitten = Restr.get('http://example.com/kittens/1.xml')
#
#   # Create a Kitten
#   kitten = Restr.post('http://example.com/kittens.xml', 
#     :name => 'batman', :color => 'black')
#
#   # Update a Kitten
#   kitten = Restr.put('http://example.com/kittens/1.xml', 
#     :age => '6 months')
#
#   # Delete a Kitten
#   kitten = Restr.delete('http://example.com/kittens/1.xml')
#
#   # Retrieve a list of Kittens
#   kittens = Restr.get('http://example.com/kittens.xml')
#
# When the response to a Restr request has content type 'text/xml', the
# response body will be parsed from XML into a nested Hash (using XmlSimple 
# -- see http://xml-simple.rubyforge.org/). Otherwise the response is  
# returned untouched, as a String.
#
# If the remote REST resource requires authentication (Restr only supports
# HTTP Basic authentication, for now):
#
#   Restr.get('http://example.com/kittens/1.xml, {}, 
#     {:username => 'foo', :password => 'bar'})
#
class Restr
  def self.method_missing(method, *args)
    self.do(method, args[0], args[1], args[2])
  end
  
  def self.do(method, url, params = {}, auth = nil)
    uri = URI.parse(url)
      
    method_mod = method.to_s.downcase.capitalize
    unless Net::HTTP.const_defined?(method_mod)
      raise InvalidMethodError, 
        "Callback method #{method.inspect} is not a valid HTTP request method."
    end
    
    if method_mod == 'Get'
      q = params.collect{|k,v| "#{CGI.escape(k)}=#{CGI.escape(v)}"}.join("&")
      if uri.query
        uri.query += "&#{q}"
      else
        uri.query = q
      end
    end
    
    req = Net::HTTP.const_get(method_mod).new(uri.request_uri)
    
    
    if auth
      raise ArgumentError, 
        "The `auth` parameter must be a Hash with a :username and :password value." unless 
        auth.kind_of? Hash
      req.basic_auth auth[:username], auth[:password]
    end
    
    unless method_mod == 'Get'
      req.set_form_data(params, ';')
    end
 
    client = Net::HTTP.new(uri.host, uri.port)
    client.use_ssl = (uri.scheme == 'https')
    res = client.start do |http|
      http.request(req)
    end
    
    case res
    when Net::HTTPSuccess
      if res.content_type == 'text/xml'
        XmlSimple.xml_in_string(res.body,
          'forcearray'   => false,
          'keeproot'     => true
        )
      else
        res.body
      end
    else
      res.error!
    end
  end
  
  class InvalidMethodError < Exception
  end
end