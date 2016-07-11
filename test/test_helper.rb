require 'spork'

ENV['RAILS_ENV'] = 'test'

# Simplecov doesn't work properly in jruby
if ENV['TRAVIS'] == true && RUBY_PLATFORM != 'java'
  require 'codacy-coverage'
  Codacy::Reporter.start
end

Spork.prefork do

  require File.expand_path('../../config/environment', __FILE__)

  require 'rails/test_help'
  require "#{Rails.root}/test/blueprints"
  require 'capybara/rails'
  require 'shoulda'
  require 'shoulda/matchers'
  require 'shoulda_macros/auth'

  include ActionMailer::TestHelper
end

DatabaseCleaner.strategy = :transaction

class ActiveSupport::TestCase

  fixtures :all
  self.use_transactional_fixtures = false
  #self.use_instantiated_fixtures  = false

  setup { Sham.reset; DatabaseCleaner.start }
  teardown { DatabaseCleaner.clean }

  # Returns a project with a few tasks.
  # Milestones will also be created if options[:make_milestones] is true
  # The project will belong to user's company and user will have full
  # access to the project.
  # The user will also be on the assigned list for the tasks.
  def project_with_some_tasks(user, options = {})
    task_count = options[:task_count] || 2
    customer = options[:customer] || user.customer || Customer.make(:company => user.company)
    make_milestones = options[:make_milestones]

    project = Project.make(:company => user.company,
                           :customer => customer)
    project.users << user
    perm = project.project_permissions.build(:user => user)
    perm.set('all')
    project.save!

    if make_milestones
      2.times { project.milestones.make }
    end

    task_count.times do
      t = TaskRecord.make(:project => project,
                          :company => project.company,
                          :users => [user],
                          :milestone => project.milestones.sample)
    end

    return project
  end

  def imagemagick_present?
    `which convert`.present?
  end
end

module ActionController
  class TestRequest
    def with_subdomain(subdomain=nil)
      the_host_name = 'www.localhost.com'
      the_host_name = "#{subdomain}.localhost.com" if subdomain
      self.host = the_host_name
      self.env['SERVER_NAME'] = the_host_name
      self.env['HTTP_HOST'] = the_host_name
    end

    def server_name
      self.env['SERVER_NAME']
    end
  end
end

class ActionController::TestCase
  # Just set the session id to login
  include Devise::TestHelpers
  extend Devise::AdminContextMacro
end

class ActionDispatch::IntegrationTest
  include Capybara::DSL

  def login
    clear_all_fixtures
    company = Company.make
    customer = Customer.make(:company => company)
    user = User.make(:customer => customer, :company => company)

    host = "#{company.subdomain}.example.com"
    Capybara.app_host = 'http://' + host
    host! host

    visit new_user_session_path
    fill_in 'user_username', :with => user.username
    fill_in 'user_password', :with => user.password
    click_button('Login')

    assert page.has_content?('Log Out'), 'link Log Out exist'
    return user
  end

  # Need to make sure fixtures don't interfere with our blueprints
  def clear_all_fixtures
    Company.delete_all
  end

  # Uses webrat to logout of the system
  def logout
    visit '/login/logout'
  end

  teardown do
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
end

class Hash
  def deep_clone
    Marshal::load(Marshal.dump(self))
  end
end
