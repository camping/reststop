#--
# This file is part of Reststop.
#
# Reststop is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Reststop is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#--


module Reststop
  unless const_defined? 'VERSION'
  	module VERSION #:nodoc:
      MAJOR = 0
      MINOR = 1
      TINY  = 0
  
      STRING = [MAJOR, MINOR, TINY].join('.')
    end
  end
end


# Extends and overrides Camping for convenient RESTfulness.
#
# Have a look at:
#
# * Camping::Controllers#REST for help on using RESTful controllers
# * Camping#render for help on grouping your views by output format
#
module Camping
  
  # Override Camping's goes() mechanism so that we can add our stuff.
  # ... there must be a saner way to do this >:|
  #
  # FIXME: looks like this breaks auto-reloading when using the camping
  #        server for launching apps :(
  S2 = IO.read(__FILE__).gsub(/^  S2 = I.+$/,'') # :nodoc:
  class << self
    alias_method :camping_goes, :goes 
    def goes(m) # :nodoc:
      camping_goes m
      eval S2.gsub('Camping', m.to_s), TOPLEVEL_BINDING
    end
  end
  
  # This override is stolen and slightly modified from the Camping mailing list;
  # it fakes PUT/DELETE HTTP methods, since many browsers don't support them.
  #
  # In your forms you will have to add:
  #
  # input :name => '_method', :type => 'hidden', :value => 'VERB'
  #
  # ... where VERB is one of put, post, or delete. The form's actual :method 
  # parameter must be 'post' (i.e. :method => post).
  #
  def service(*a)
    if @method == 'post' && (input._method == 'put' || input._method == 'delete')
      @env['REQUEST_METHOD'] = input._method.upcase
      @method = input._method
    end
    super(*a)
  end
  
  # Overrides Camping's render method to add the ability to specify a format 
  # module when rendering a view.
  #
  # The format can also be specified in other ways (shown in this order 
  # of precedence):
  #
  #   # By providing a second parameter to render()
  #     (eg: <tt>render(:foo, :HTML)</tt>)
  #   # By setting the @format variable
  #   # By providing a 'format' parameter in the request (i.e. @input[:format])
  #   # By adding a file-format extension to the url (e.g. /items.xml or 
  #     /items/2.html).
  #
  # For example, you could have:
  #
  #   module Foobar::Views
  #
  #     module HTML
  #       def foo
  #         # ... render some HTML content
  #       end
  #     end
  #
  #     module RSS
  #       def foo
  #         # ... render some RSS content
  #       end
  #     end
  #
  #   end
  #
  # Then in your controller, you would call render() like this:
  #
  #   render(:foo, :HTML) # render the HTML version of foo
  #
  # or
  #
  #   render(:foo, :RSS) # render the RSS version of foo
  #
  # or
  #
  #   @format = :RSS
  #   render(:foo) # render the RSS version of foo
  #
  # or
  # 
  #   # url is /foobar/1?format=RSS
  #   render(:foo) # render the RSS version of foo
  #
  # or 
  #
  #   # url is /foobar/1.rss
  #   render(:foo) # render the RSS version of foo
  #
  # If no format is specified, render() will behave like it normally does in 
  # Camping, by looking for a matching view method directly
  # in the Views module.
  #
  # You can also specify a default format module by calling 
  # <tt>default_format</tt> after the format module definition.
  # For example:
  #
  #   module Foobar::Views
  #     module HTML
  #       # ... etc.
  #     end
  #     default_format :HTML
  #   end
  #
  def render(action, format = nil)
    format ||= @format
    
    if format.nil?
      begin
        ct = CONTENT_TYPE
      rescue NameError
        ct = 'text/html'
      end
      @headers['Content-Type'] = ct
      
      super(action)
    else
      m = Mab.new({}, self)
      mod = "Camping::Views::#{format.to_s}".constantize
      m.extend mod
      
      begin
        ct = mod::CONTENT_TYPE
      rescue NameError
        ct = 'text/html'
      end
      @headers['Content-Type'] = ct
    
      s = m.capture{m.send(action)}
      s = m.capture{send(:layout){s}} if /^_/!~a[0].to_s and m.respond_to?(:layout)
      s
    end
  end

  # See Camping#render
  module Views
    class << self
      # Call this inside your Views module to set a default format.
      #
      # For example:
      #
      #   module Foobar::Views
      #     module HTML
      #       # ... etc.
      #     end
      #     default_format :XML
      #   end
      def default_format(m)
        mod = "Camping::Views::#{m.to_s}".constantize
        Mab.class_eval{include mod}
      end
    end
  end
  
  module Controllers
    def read_format #:nodoc:
      if @input[:format]
        @input[:format].upcase.intern
      elsif @env['PATH_INFO'] =~ /\.([a-z]+)$/
        $~[1].upcase.intern
      end
    end
    
    class << self
      # Calling <tt>REST "<resource name>"</tt> creates a controller with the
      # appropriate routes and maps your REST methods to standard
      # Camping controller mehods. This is meant to be used in your Controllers
      # module in place of <tt>R <routes></tt>.
      #
      # Your REST class should define the following methods:
      # 
      # * create
      # * read(id)
      # * update(id)
      # * destroy(id)
      # * list
      # 
      # Routes will be automatically created based on the resource name fed to the
      # REST method. Note that your class must have the same (but CamelCaps'ed) 
      # name as the resource name. So if your resource name is 'kittens', 
      # your controller class must be Kittens.
      #
      # For example:
      #
      #   module Foobar::Controllers
      #     class Kittens < REST 'kittens'
      #       # POST /kittens
      #       def create
      #       end
      #
      #       # GET /kittens/(\d+)
      #       def read(id)
      #       end
      #
      #       # PUT /kittens/(\d+)
      #       def update(id)
      #       end
      #
      #       # DELETE /kittens/(\d+)
      #       def destroy(id)
      #       end
      #
      #       # GET /kittens
      #       def list
      #       end
      #     end
      #   end
      #
      #
      # Optionally, you can specify a :prefix key that will prepend this
      # string to the routes. For example, this will create all of the above
      # routes, prefixed with '/pets' (i.e. POST '/pets/kittens', 
      # GET '/pets/kittens/(\d+)', etc.)
      #
      #   module Foobar::Controllers
      #     class Items < REST 'kittens', :prefix => '/pets'
      #       # ...
      #     end
      #   end
      #
      # Additionally, format-based routing is possible. For example to get 
      # a list of kittens in XML format, place a GET call to /kittens.xml.
      # See the documentation for the render() method for more info.
      #
      def REST(r, options = {})
        crud = R "#{options[:prefix]}/#{r}(?:\.[a-z]+)?/(.+)", "#{options[:prefix]}/#{r}(?:\.[a-z]+)?"
        crud.module_eval do
          
          def get(id = nil) # :nodoc:
            @format = read_format
            puts "FORMAT: #{@format}"
            if id.nil? && @input[:id].nil?
               list
            else
              read(id || @input[:id])
            end
          end
          
          
          def post # :nodoc:
            @format = read_format
            create
          end
          
          
          def put(id = nil) # :nodoc:
            @format = read_format
            update(id || @input[:id])
          end
          
          
          def delete(id = nil) # :nodoc:
            @format = read_format
            destroy(id || @input[:id])
          end
        end
        crud
      end
    end
  end
end