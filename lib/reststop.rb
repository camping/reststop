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


# Convenient RESTfulness for all your Camping controller needs.
#
# To use, call `REST '<resource name>'` instead of `R <routes>` in your 
# Controllers module, then define methods for the standard CRUD verbs
# ('create', 'read', 'update', 'delete') and also  'list'. 
# 
# Routes will be created automatically based on the parameters fed to 
# REST. Note that your class must have the same (but CamelCaps'ed) name as
# the resource name to provide to REST. So if you said 'kittens', your 
# controller class must be 'Kittens'.
#
# For example:
#
#   module Foobar::Controllers
#     class Items < REST 'items'
#       # POST /items
#       def create
#       end
#
#       # GET /items/(\d+)
#       def read(id)
#       end
#
#       # PUT /items/(\d+)
#       def update(id)
#       end
#
#       # DELETE /items/(\d+)
#       def destroy(id)
#       end
#
#       # GET /items
#       def list
#       end
#     end
#   end
#
#
# Optionally, you can specify a :prefix option that will prepend this
# string to the routes. For example, this will create all of the above
# routes, prefixed with '/stuff' (i.e. POST '/stuff/items', 
# GET '/stuff/items/(\d+)', etc.)
#
#   module Foobar::Controllers
#     class Items < REST 'items', :prefix => '/stuff'
#       # ...
#     end
#   end


module Camping
  
  # Override Camping's goes() mechanism so that we can add our stuff.
  # ... there must be a saner way to do this >:|
  S2 = IO.read(__FILE__).gsub(/^  S2 = I.+$/,'')
  class << self
    alias_method :camping_goes, :goes
    def goes(m)
      camping_goes m
      eval S2.gsub('Camping', m.to_s), TOPLEVEL_BINDING
    end
  end
  
  # This snippet is stolen and slightly modified from the Camping mailing list;
  # it fakes PUT/DELETE HTTP methods, since many browsers don't support this.
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
  
  # Adds ability to specify a format when rendering a view.
  #
  # Format is specified in one of three ways (in this order of precedence):
  #
  #   # By providing a second parameter to render()
  #     (eg: <tt>render(:foo, :HTML)</tt>)
  #   # By setting the @format variable
  #   # By providing a 'format' parameter in the request (i.e. @input[:format])
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
  #     default_format :XML
  #   end
  #
  def render(action, format = nil)
    format ||= @format || @input[:format]
    
    if format.nil?
      super(action)
    else
      m = Mab.new({}, self)
      mod = "Camping::Views::#{format.to_s}".constantize
      m.extend mod
      s = m.capture{m.send(action)}
      s = m.capture{send(:layout){s}} if /^_/!~a[0].to_s and m.respond_to?(:layout)
      s
    end
  end

  module Views
    class << self
      def default_format(m)
        mod = "Camping::Views::#{m.to_s}".constantize
        Mab.class_eval{include mod}
      end
    end
  end
  
  module Controllers
    class << self
      # Calling `REST '<resource name>'` creates a controller with the
      # appropriate routes and maps your REST methods to standard
      # Camping controller mehods.
      def REST(r, options = {})
        crud = R "#{options[:prefix]}/#{r}/(.+)", "#{options[:prefix]}/#{r}"
        crud.module_eval do
          def get(id = nil)
            if id.nil? && @input[:id].nil?
               list
            else
              read(id || @input[:id])
            end
          end
          
          def post   
            create
          end
          
          def put(id = nil)
            update(id || @input[:id])
          end
          
          def delete(id = nil)
            destroy(id || @input[:id])
          end
        end
        crud
      end
    end
  end
end