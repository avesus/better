# BetterMeans - Work 2.0
# Copyright (C) 2006-2008  Shereef Bishay
#

require File.dirname(__FILE__) + '/../test_helper'
require 'repositories_controller'

# Re-raise errors caught by the controller.
class RepositoriesController; def rescue_action(e) raise e end; end

class RepositoriesMercurialControllerTest < ActionController::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :repositories, :enabled_modules

  # No '..' in the repository path
  REPOSITORY_PATH = RAILS_ROOT.gsub(%r{config\/\.\.}, '') + '/tmp/test/mercurial_repository'

  def setup
    @controller = RepositoriesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
    Repository::Mercurial.create(:project => Project.find(3), :url => REPOSITORY_PATH)
  end
  
  if File.directory?(REPOSITORY_PATH)
    def test_show
      get :show, :id => 3
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_not_nil assigns(:changesets)
    end
    
    def test_show_root
      get :show, :id => 3
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal 3, assigns(:entries).size
      assert assigns(:entries).detect {|e| e.name == 'images' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'sources' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'README' && e.kind == 'file'}
    end
    
    def test_show_directory
      get :show, :id => 3, :path => ['images']
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal ['delete.png', 'edit.png'], assigns(:entries).collect(&:name)
      entry = assigns(:entries).detect {|e| e.name == 'edit.png'}
      assert_not_nil entry
      assert_equal 'file', entry.kind
      assert_equal 'images/edit.png', entry.path
    end
    
    def test_show_at_given_revision
      get :show, :id => 3, :path => ['images'], :rev => 0
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal ['delete.png'], assigns(:entries).collect(&:name)
    end
    
    def test_changes
      get :changes, :id => 3, :path => ['images', 'edit.png']
      assert_response :success
      assert_template 'changes'
      assert_tag :tag => 'h2', :content => 'edit.png'
    end
    
    def test_entry_show
      get :entry, :id => 3, :path => ['sources', 'watchers_controller.rb']
      assert_response :success
      assert_template 'entry'
      # Line 19
      assert_tag :tag => 'th',
                 :content => /10/,
                 :attributes => { :class => /line-num/ },
                 :sibling => { :tag => 'td', :content => /WITHOUT ANY WARRANTY/ }
    end
    
    def test_entry_download
      get :entry, :id => 3, :path => ['sources', 'watchers_controller.rb'], :format => 'raw'
      assert_response :success
      # File content
      assert @response.body.include?('WITHOUT ANY WARRANTY')
    end

    def test_directory_entry
      get :entry, :id => 3, :path => ['sources']
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entry)
      assert_equal 'sources', assigns(:entry).name
    end
    
    def test_diff
      # Full diff of changeset 4
      get :diff, :id => 3, :rev => 4
      assert_response :success
      assert_template 'diff'
      # Line 22 removed
      assert_tag :tag => 'th',
                 :content => /22/,
                 :sibling => { :tag => 'td', 
                               :attributes => { :class => /diff_out/ },
                               :content => /def remove/ }
    end
    
    def test_annotate
      get :annotate, :id => 3, :path => ['sources', 'watchers_controller.rb']
      assert_response :success
      assert_template 'annotate'
      # Line 23, revision 4
      assert_tag :tag => 'th', :content => /23/,
                 :sibling => { :tag => 'td', :child => { :tag => 'a', :content => /4/ } },
                 :sibling => { :tag => 'td', :content => /jsmith/ },
                 :sibling => { :tag => 'td', :content => /watcher =/ }
    end
  else
    puts "Mercurial test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end
end
