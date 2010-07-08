# Right now you'll have to do some weird gymnastics to get this hooked in to a Camping app...
# Something like:
#
#   Camping.goes :Blog
# 
#   module Blog
#     include Camping::Session
#     include Reststop
#  
#     Controllers.extend Reststop::Controllers
#   end
# 
#   module Blog::Base
#     alias camping_render render
#     alias camping_service service
#		alias camping_lookup lookup
#     include Reststop::Base
#     alias service reststop_service
#     alias render reststop_render
#
#	# Overrides the new Tilt-centric lookup method In camping
#	# RESTstop needs to have a first try at looking up the view
#	# located in the Views::HTML module. 
#   def lookup(n)
#      T.fetch(n.to_sym) do |k|
#        t = Blog::Views::HTML.method_defined?(k) || camping_lookup(n)
#      end
#    end

#   end
#   
#   module Blog::Controllers
#     extend Reststop::Controllers
#     ...
#   end
#   
#   module Blog::Helpers
#     alias_method :_R, :R
#     remove_method :R
#     include Reststop::Helpers
#     ...
#   end
#   
#   module Blog::Views
#     extend Reststop::Views
#     ...
#   end
#
# The hope is that this could all get taken care of in a
# `include Reststop` call (via overriding of #extended)
#
# See examples/blog.rb for a working example.
require 'logger'
$LOG = Logger.new(STDOUT)

module Reststop
  module Base
    def reststop_service(*a)
      if @env['REQUEST_METHOD'] == 'POST' && (input['_method'] == 'put' || input['_method'] == 'delete')
        @env['REQUEST_METHOD'] = input._method.upcase
        @method = input._method
      end
  	  @a0=a[0] if !a.empty?
      camping_service(*a)
    end

    # Overrides Camping's render method to add the ability to specify a format
    # module when rendering a view.
    #
    # The format can also be specified in other ways (shown in this order
    # of precedence):
    #
    # 1. By providing a second parameter to render()
    #    (eg: <tt>render(:foo, :HTML)</tt>)
    # 2. By setting the @format variable
    # 3. By providing a 'format' parameter in the request (i.e. input[:format])
    # 4. By adding a file-format extension to the url (e.g. /items.xml or
    #    /items/2.html).
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
    def reststop_render(action, format = nil)
	  format = nil unless format.is_a? Symbol

	  app_name = self.class.name.split("::").first							# @techarch : get the name of the app
	  format ||= @format

      if format.nil?
        begin
          ct = CONTENT_TYPE
        rescue NameError
          ct = 'text/html'
        end

        @headers['Content-Type'] ||= ct
   		basic_render(action) # @techarch
      else
        mab = (app_name + '::Mab').constantize								# @techarch : get the Mab class
    	m = mab.new({}, self)																# @techarch : instantiate Mab
    	mod = (app_name + "::Views::#{format.to_s}").constantize	# @techarch : get the right Views format class

        m.extend mod

        begin
          ct = mod::CONTENT_TYPE
        rescue NameError
          ct = "#{format == :HTML ? 'text' : 'application'}/#{format.to_s.downcase}" #@techarch - used to be text/***
        end
        @headers['Content-Type'] = ct

        s = m.capture{m.send(action)}
        s = m.capture{send(:layout){s}} if /^_/!~action.to_s and m.respond_to?(:layout)	
        s
      end
    end
	
	# Performs a basic camping rendering (without use of a layout)
	# This method was added since the addition of Tilt support in camping 
	# is assuming layout.
	def basic_render(action)
		app_name = self.class.name.split("::").first							# @techarch : get the name of the app
        	mab = (app_name + '::Mab').constantize								# @techarch : get the Mab class
   		m = mab.new({}, self)														# @techarch : instantiate Mab
		
		tpl = lookup(action)	# check if we have a Tilt template
		
		raise "Can't find action #{action}" unless tpl
		
		s = (tpl == true) ? m.capture{m.send(action)} : tpl.render(self, {}) # if so render it
		if /^_/!~action.to_s
			layout_tpl = lookup(:layout)
			if layout_tpl
				b = Proc.new { s }
				s = (layout_tpl == true) ? m.capture{send(:layout){s}} : layout_tpl.render(m, {},&b) # if so render it
			end
		end
		s
	end
  end

  
  module Views
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
      mod = "#{self}::#{m.to_s}".constantize
      mab = self.to_s.gsub('::Views','::Mab').constantize		# @techarch : get the Mab class
      mab.class_eval{include mod}
    end
  end

  module Helpers
    # Overrides Camping's routing helper to make it possible to route RESTful resources.
    #
    # Some usage examples:
    #
    #   R(Kittens)            # /kittens
    #   R(Kittens, 'new')     # /kittens/new
    #   R(Kittens, 1, 'meow') # /kittens/1/meow
    #   R(@kitten)            # /kittens/1
    #   R(@kitten, 'meow')    # /kittens/1/meow
    #   R(Kittens, 'list', :colour => 'black')  # /kittens/list?colour=black
    #
    # The current output format is retained, so if the current <tt>@format</tt> is <tt>:XML</tt>,
    # the URL will be /kittens/1.xml rather than /kittens/1.
    #
    # Note that your controller names might not be loaded if you're calling <tt>R</tt> inside a
    # view module. In that case you should use the fully qualified name (i.e. Myapp::Controllers::Kittens)
    # or include the Controllers module into your view module.
    def R(c, *g)

		cl = c.class.name.split("::").last.pluralize
		app_name = c.class.name.split("::").first
		ctrl_cl = app_name + '::Controllers'				# @techarch : get to the Controllers using the current app
		ctrl = (app_name != 'Class') ? ctrl_cl.constantize : Controllers
		
		if ctrl.constants.include?(cl)				#@techarch updated to use new cl variable
			path = "/#{cl.underscore}/#{c.id}"
			path << ".#{@format.to_s.downcase}" if @format
			path << "/#{g.shift}" unless g.empty?
			self / path
		  elsif c.respond_to?(:restful?) && c.restful?
			base = c.name.split("::").last.underscore
			id_or_action = g.shift  
			if id_or_action.to_s =~ /\d+/			#@techarch needed a to_s after id_or_action to allow pattern matching
			  id = id_or_action
			  action = g.shift
			else
			  action = id_or_action
			end

			path = "/#{base}"
			path << "/#{id}" if id
			path << "/#{action}" if action
			path << ".#{@format.to_s.downcase}" if @format
			
			#@techarch substituted U for u=Rack::Utils
			u=Rack::Utils
			path << "?#{g.collect{|a|a.collect{|k,v| u.escape(k)+"="+u.escape(v)}.join("&")}.join("&")}" unless g.empty? # FIXME: undefined behaviour if there are multiple arguments left
			return path
		else
			_R(c, *g)
		end
	end # def R
  end # module Helpers

  module Controllers
    def self.determine_format(input, env) #:nodoc:
      if input[:format] && !input[:format].empty?
        input[:format].upcase.intern
      elsif env['PATH_INFO'] =~ /\.([a-z]+)$/
        $~[1].upcase.intern
      end
    end

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
    # REST method. <b>Your class must have the same (but CamelCaps'ed)
    # name as the resource name.</b> So if your resource name is 'kittens',
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
    # Custom actions are also possible. For example, to implement a 'meow'
    # action simply add a 'meow' method to the above controller:
    #
    #   # POST/GET/PUT/DELETE /kittens/meow
    #   # POST/GET/PUT/DELETE /kittens/(\d+)/meow
    #   def meow(id)
    #   end
    #
    # Note that a custom action will respond to all four HTTP methods
    # (POST/GET/PUT/DELETE).
    #
    # Optionally, you can specify a <tt>:prefix</tt> key that will prepend the
    # given string to the routes. For example, the following will create all
    # of the above routes, prefixed with "/pets"
    # (i.e. <tt>POST '/pets/kittens'</tt>,  <tt>GET '/pets/kittens/(\d+)'</tt>,
    # etc.):
    #
    #   module Foobar::Controllers
    #     class Items < REST 'kittens', :prefix => '/pets'
    #       # ...
    #     end
    #   end
    #
    # Format-based routing similar to that in ActiveResource is also implemented.
    # For example, to get a list of kittens in XML format, place a
    # <tt>GET</tt> call to <tt>/kittens.xml</tt>.
    # See the documentation for the render() method for more info.
    #
    def REST(r, options = {})
      crud = R "#{options[:prefix]}/#{r}/([0-9a-zA-Z]+)/([a-z_]+)(?:\.[a-z]+)?",
        "#{options[:prefix]}/#{r}/([0-9a-zA-Z]+)(?:\.[a-z]+)?",
        "#{options[:prefix]}/#{r}/([a-z_]+)(?:\.[a-z]+)?",
        "#{options[:prefix]}/#{r}(?:\.[a-z]+)?"

      crud.module_eval do
        meta_def(:restful?){true}

        $LOG.debug("Creating RESTful controller for #{r.inspect} using Reststop #{'pull version number here'}") if $LOG

        def get(id_or_custom_action = nil, custom_action =  nil) # :nodoc:
          id = input['id'] if input['id']

          custom_action = input['action'] if input['action']

          if self.methods.include? id_or_custom_action
            custom_action ||= id_or_custom_action
            id ||= nil
          else
            id ||= id_or_custom_action
          end

          id = id.to_i if id && id =~ /^[0-9]+$/

          @format = Reststop::Controllers.determine_format(input, @env)

          begin
            if id.nil? && input['id'].nil?
              custom_action ? send(custom_action) : list
            else
              custom_action ? send(custom_action, id || input['id']) : read(id || input['id'])
            end
          rescue NoMethodError => e
            # FIXME: this is probably not a good way to do this, but we need to somehow differentiate
            #        between 'no such route' vs. other NoMethodErrors
            if e.message =~ /no such method/
              return no_method(e)
            else
              raise e
            end
          rescue ActiveRecord::RecordNotFound => e
            return not_found(e)
          end
        end


        def post(custom_action = nil) # :nodoc:
          @format = Reststop::Controllers.determine_format(input, @env)
          custom_action ? send(custom_action) : create
        end

        def put(id, custom_action = nil) # :nodoc:
          id = id.to_i if id =~ /^[0-9]+$/
          @format = Reststop::Controllers.determine_format(input, @env)
          custom_action ? send(custom_action, id || input['id']) : update(id || input['id'])
        end

        def delete(id, custom_action = nil) # :nodoc:
          id = id.to_i if id =~ /^[0-9]+$/
          @format = Reststop::Controllers.determine_format(input, @env)
          custom_action ? send(custom_action, id || input['id']) : destroy(id || input['id'])
        end

        private
        def _error(message, status_code = 500, e = nil)
          @status = status_code
          @message = message
          begin
            render "error_#{status_code}".intern
          rescue NoMethodError
            if @format.to_s == 'XML'
              "<error code='#{status_code}'>#{@message}</error>"
            else
              out  = "<strong>#{@message}</strong>"
              out += "<pre style='color: #bbb'><strong>#{e.class}: #{e}</strong>\n#{e.backtrace.join("\n")}</pre>" if e
              out
            end
          end
        end

        def no_method(e)
          _error("No controller method responds to this route!", 501, e)
        end

        def not_found(e)
          _error("Record not found!", 404, e)
        end
      end
      crud
    end # def REST
  end # module Controllers
end # module Reststop

module Markaby
  class Builder
    # Modifies Markaby's 'form' generator so that if a 'method' parameter
    # is supplied, a hidden '_method' input is automatically added. 
    def form(*args, &block)
      options = args[0] if args && args[0] && args[0].kind_of?(Hash)
      inside = capture &block
      
      if options && options.has_key?(:method)
        inside = input(:type => 'hidden', :name => '_method', :value => options[:method]) +
          inside
        if options[:method].to_s === 'put' || options[:method].to_s == 'delete'
          options[:method] = 'post'
        end
      end
      
      tag!(:form, options || args[0]) {inside}
    end
  end
end
