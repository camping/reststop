#!/usr/bin/env ruby

require 'rubygems'
#require 'ruby-debug'			# @techarch : commented out since only needed for local debugging

require 'markaby'					# @techarch : added explicit require
require 'camping'					# @techarch
require 'camping/session'	# @techarch : added explicit require since session has changed in Camping 2.0

gem 'RedCloth'						# @techarch : added since it is referenced in the Posts model
require 'redcloth'				# @techarch : added

#gem 'camping', '~> 2.0'
gem 'camping' , '>= 2.0'	# @techarch : updated version

#gem 'reststop', '~> 0.3'

=begin										# @techarch : commented out since only needed for local debugging
$: << '../../camping/lib'
$: << '../lib'
require 'camping-unabridged'
require 'camping/ar'
require 'camping/session'
=end

#begin										# @techarch : commented out since only needed for local debugging
  # try to use local copy of library
  #require '../lib/reststop2'
  $: << '../lib/'
  require 'reststop.rb'			# @techarch : adjusted so that it is located in the same current folder
#rescue LoadError
#  # ... otherwise default to rubygem
#  require 'reststop'
#end

Camping.goes :Blog

module Blog
  include Camping::Session
  include Reststop
 
  Controllers.extend Reststop::Controllers
end

module Blog::Base
  alias camping_render render
  alias camping_lookup lookup	# @techarch: required if camping > 2.0
  alias camping_service service
  include Reststop::Base
  alias service reststop_service
  alias render reststop_render
  
	# Overrides the new Tilt-centric lookup method In camping
	# RESTstop needs to have a first try at looking up the view
	# located in the Views::HTML module. 
    def lookup(n)
      T.fetch(n.to_sym) do |k|
        t = Blog::Views::HTML.method_defined?(k) || camping_lookup(n)
      end
    end
end

module Blog::Models
  class Post < Base
    belongs_to :user

    before_save do |record|
       cloth = RedCloth.new(record.body)
       cloth.hard_breaks = false
       record.html_body = cloth.to_html
    end
  end

  class Comment < Base; belongs_to :user; end
  class User < Base; end

  class BasicFields < V 1.1
    def self.up
      create_table :blog_posts, :force => true do |t|
        t.integer :user_id,          :null => false
        t.string  :title,            :limit => 255
        t.text    :body, :html_body
        t.timestamps
      end
      create_table :blog_users, :force => true do |t|
        t.string  :username, :password
      end
      create_table :blog_comments, :force => true do |t|
        t.integer :post_id,          :null => false
        t.string  :username
        t.text    :body, :html_body
        t.timestamps
      end
      User.create :username => 'admin', :password => 'camping'
    end

    def self.down
      drop_table :blog_posts
      drop_table :blog_users
      drop_table :blog_comments
    end
  end
end

module Blog::Controllers
  extend Reststop::Controllers
    class Index
		def get
			redirect '/posts'
		end
	end
	
	class Login < R '/login'		# @techarch : added explicit login controller	
		def get
			render :_login
		end
	end
	
    class Posts < REST 'posts'      
      # POST /posts
      def create
        require_login!
        @post = Post.create :title => (input.post_title || input.title),	# @techarch : allow for REST-client based update 
		  :body => (input.post_body || input.body),								# @techarch : allow for REST-client based update
          :user_id => @state.user_id
        redirect R(@post)	
      end

      # GET /posts/1
      # GET /posts/1.xml
      def read(post_id)
        @post = Post.find(post_id)
        @comments = Models::Comment.find(:all, :conditions => ['post_id = ?', post_id])
        render :view
      end

      # PUT /posts/1
      def update(post_id)
        require_login!
        @post = Post.find(post_id)
        @post.update_attributes :title => (input.post_title || input.title),	# @techarch : allow for REST-client based update 
			:body => (input.post_body || input.body)									# @techarch : allow for REST-client based update 
        redirect R(@post)
      end

      # DELETE /posts/1
      def delete(post_id)
        require_login!
        @post = Post.find post_id

        if @post.destroy
          redirect R(Posts)
        else
          _error("Unable to delete post #{@post.id}", 500)
        end
      end

      # GET /posts
      # GET /posts.xml
      def list
        @posts = Post.all(:order => 'updated_at DESC')
        s=render :index
		s
      end

      # GET /posts/new
      def new
        #@state.user_id = 1		# @techarch : commented out as was probably hard-coded for testing purpose
        require_login!
		@user = User.find @state.user_id	# @techarch : added since we need the user info
        @post = Post.new
        render :add
      end

      # GET /posts/1/edit
      def edit(post_id)
        require_login!
 		@user = User.find @state.user_id	# @techarch : added since we need the user info
        @post = Post.find(post_id)
        render :edit
      end
    end
     
    class Comments < REST 'comments'
      # POST /comments
      def create
        Models::Comment.create(:username => (input.post_username || input.username),	# @techarch : allow for REST-client based		update 
			:body => (input.post_body || input.body),	# @techarch : allow for REST-client based update  
			:post_id => input.post_id)
        redirect R(Posts, input.post_id)
      end
    end

    class Sessions < REST 'sessions'
        # POST /sessions
        def create
          @user = User.find_by_username_and_password(input.username, input.password)

          if @user
            @state.user_id = @user.id
            redirect R(Posts)
          else
            @info = 'Wrong username or password.'
          end
          render :login
        end   

        # DELETE /sessions
        def delete
          @state.user_id = nil
          redirect R(Posts) 		# @techarch : changed redirect from Index (does not exist) to Posts
        end
    end
    
    # You can use old-fashioned Camping controllers too!
    class Style < R '/styles.css'
      def get
        @headers["Content-Type"] = "text/css; charset=utf-8"
        @body = %{
          body {
              font-family: Utopia, Georga, serif;
          }
          h1.header {
              background-color: #fef;
              margin: 0; padding: 10px;
          }
          div.content {
              padding: 10px;
          }
        }
      end
    end
end

module Blog::Helpers
  alias_method :_R, :R
  remove_method :R
  include Reststop::Helpers

  def logged_in?
    !!@state.user_id
  end

  def require_login!
    unless logged_in?
      redirect(R(Blog::Controllers::Login))	# @techarch: add explicit route
      throw :halt
    end
  end
end


module Blog::Views
  extend Reststop::Views
  
  module HTML
    include Blog::Controllers
    include Blog::Views

    def layout
      html do
        head do
          title 'blog'
          link :rel => 'stylesheet', :type => 'text/css',
               :href => self/'/styles.css', :media => 'screen'
        end
        body do
          h1.header { a 'blog', :href => R(Posts) }
          div.content do
            self << yield
          end
        end
      end
    end

    def index
      if @posts.empty?
        p 'No posts found.'
      else
        for post in @posts
          _post(post)
        end
      end
      p { a 'Add', :href => R(Posts, 'new') }
    end

    def login
      p { b @login }
      p { a 'Continue', :href => R(Posts, 'new') }
    end

    def logout
      p "You have been logged out."
      p { a 'Continue', :href => R(Posts) }
    end

    def add
      if @user
        _form(@post, :action => R(Posts))
      else
        _login
      end
    end

    def edit
      if @user
        _form(@post, :action => R(@post), :method => :put) 
      else
        _login
      end
    end

    def view
      _post(@post)

      p "Comment for this post:"
      for c in @comments
        h1 c.username
        p c.body
      end

      form :action => R(Comments), :method => 'post' do
        label 'Name', :for => 'post_username'; br
        input :name => 'post_username', :type => 'text'; br
        label 'Comment', :for => 'post_body'; br
        textarea :name => 'post_body' do; end; br
        input :type => 'hidden', :name => 'post_id', :value => @post.id
        input :type => 'submit'
      end
    end

    # partials
    def _login
      p do
        "(default: admin/camping)"
      end
      form :action => R(Sessions), :method => 'post' do
        label 'Username', :for => 'username'; br
        input :name => 'username', :type => 'text'; br

        label 'Password', :for => 'password'; br
        input :name => 'password', :type => 'text'; br

        input :type => 'submit', :name => 'login', :value => 'Login'
      end
    end

    def _post(post)
      h1 post.title
      p post.body
      p do
        [a("Edit", :href => R(Posts, post.id, 'edit')), a("View", :href => R(Posts, post.id, 'edit'))].join " | "
      end
    end

    def _form(post, opts)
      form(:action => R(Sessions), :method => 'delete') do
      p do
        span "You are logged in as #{@user.username}"
        span " | "
        button(:type => 'submit') {'Logout'}
      end
      end
      form({:method => 'post'}.merge(opts)) do
        label 'Title', :for => 'post_title'; br
        input :name => 'post_title', :type => 'text',
              :value => post.title; br

        label 'Body', :for => 'post_body'; br
        textarea post.body, :name => 'post_body'; br

        input :type => 'hidden', :name => 'post_id', :value => post.id
        input :type => 'submit'
      end
    end
  end
  default_format :HTML

  module XML
    def layout
      yield
    end

    def index
      @posts.to_xml(:root => 'blog')
    end

    def view
      @post.to_xml(:root => 'post')
    end
  end
end
 
def Blog.create
  raise "You must configure the database first in 'config/database.yml'!" unless File.exist?('config/database.yml')
 	dbconfig = YAML.load(File.read('config/database.yml'))								# @techarch
	Camping::Models::Base.establish_connection  dbconfig['development']		# @techarch

	Blog::Models.create_schema :assume => (Blog::Models::Post.table_exists? ? 1.0 : 0.0)
end
