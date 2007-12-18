#!/usr/bin/env ruby

#
# This is a RESTful version of the Camping-based Blog application.
#
# The original version can be found here: 
# http://code.whytheluckystiff.net/camping/browser/trunk/examples/blog.rb
#

require 'rubygems'

gem 'camping', '~> 1.5'
gem 'reststop', '~> 0.2'

require 'camping'
require 'camping/db'
require 'camping/session'

begin
  # try to use local copy of library
  require '../lib/reststop'
rescue LoadError
  # ... otherwise default to rubygem
  require 'reststop'
end
  
Camping.goes :Blog

module Blog
    include Camping::Session
end

module Blog::Models
    class Post < Base
        belongs_to :user
        has_many :comments
    end
    class Comment < Base
        belongs_to :user
    end
    class User < Base; end

    class CreateTheBasics < V 1.0
      def self.up
        create_table :blog_posts do |t|
          t.column :user_id,  :integer, :null => false
          t.column :title,    :string,  :limit => 255
          t.column :body,     :text
        end
        create_table :blog_users do |t|
          t.column :username, :string
          t.column :password, :string
        end
        create_table :blog_comments do |t|
          t.column :post_id,  :integer, :null => false
          t.column :username, :string
          t.column :body,     :text
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
    class Posts < REST 'posts'      

        # POST /posts
        def create
            unless @state.user_id.blank?
                post = Post.create :title => input.post_title, :body => input.post_body,
                                   :user_id => @state.user_id
                redirect R(Posts)
            else
              _error("Unauthorized", 401)
            end
        end

        # GET /posts/1
        # GET /posts/1.xml
        def read(post_id) 
            @post = Post.find post_id
            @comments = Models::Comment.find :all, :conditions => ['post_id = ?', post_id]
            render :view
        end

        # PUT /posts/1
        def update(post_id)
            unless @state.user_id.blank?
                @post = Post.find post_id
                @post.update_attributes :title => input.post_title, :body => input.post_body
                redirect R(@post)
            else
              _error("Unauthorized", 401)
            end
        end

        # DELETE /posts/1
        def delete(post_id)
            unless @state.user_id.blank?
                @post = Post.find post_id
                
                if @post.destroy
                  redirect R(Posts)
                else
                  _error("Unable to delete post #{@post.id}", 500)
                end
            else
              _error("Unauthorized", 401)
            end
        end

        # GET /posts
        # GET /posts.xml
        def list
            @posts = Post.find :all
            render :index
        end
        
        
        # GET /posts/new
        def new
            unless @state.user_id.blank?
                @user = User.find @state.user_id
                @post = Post.new
            end
            render :add
        end

        # GET /posts/1/edit
        def edit(post_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @post = Post.find post_id
            render :edit
        end
        
        # GET /posts/info
        def info
            div do
                code args.inspect; br; br
                code @env.inspect; br
                code "Link: #{R(Info, 1, 2)}"
            end
        end
    end
     
    class Comments < REST 'comments'
        # POST /comments
        def create
            Models::Comment.create(:username => input.post_username,
                       :body => input.post_body, :post_id => input.post_id)
            redirect R(Posts, input.post_id)
        end
    end
    
    class Sessions < REST 'sessions'
        # POST /sessions
        def create
            @user = User.find :first, :conditions => ['username = ? AND password = ?', input.username, input.password]
     
            if @user
                @login = 'login success !'
                @state.user_id = @user.id
            else
                @login = 'wrong user name or password'
            end
            render :login
        end   

        # DELETE /sessions
        def delete
            @state.user_id = nil
            render :logout
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


Markaby::Builder.set(:indent, 2)

module Blog::Views
    module HTML
        include Blog::Controllers 
      
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
    Camping::Models::Session.create_schema
    Blog::Models.create_schema :assume => (Blog::Models::Post.table_exists? ? 1.0 : 0.0)
end

