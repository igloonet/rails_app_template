# IglooNET Rails app generator
#
# TODO: add testing frameworks? probably rpsec, cucumber, capybara-webkit, factory_girl
#       add cancan? let's wait for 2.0
#       add/ask whenever for cron management?
#       ask about gravtastic?
#       ask about paper_trail?

## EVERGREEN GEMS SETUP
gem "rein"
gem "mysql2"
# rails 3.1 requirement, may be removed in future
gem 'execjs'
# rails 3.1 requirement, may be removed in future
gem 'therubyracer'


## METRICS?
if yes?("Do you want to use metrics with metrical?")
  gem("metrical", :group => :development)
end

# ActiveRecord plugins
if yes?("Use kaminari as paginator?")
  gem "kaminari"
  generate "kaminari:config"
end
if yes?("Use squeel for better AR conditions syntax?")
  gem "squeel"
  initializer 'squeel.rb', <<-CODE
Squeel.configure do |config|
  # To load hash extensions (to allow for AND (&), OR (|), and NOT (-) against
  # hashes of conditions)
  # config.load_core_extensions :hash

  # To load symbol extensions (for a subset of the old MetaWhere functionality,
  # via ARel predicate methods on Symbols: :name.matches, etc)
  # config.load_core_extensions :symbol

  # To load both hash and symbol extensions
  config.load_core_extensions :hash, :symbol
end
CODE
end
if yes?("Use ransack for easy filtering and searching?")
  gem "ransack"
end

## PRY INTEGRATION
if yes?("Use Pry instead of IRB?")
  gem "pry"
  initializer 'pry.rb', <<-CODE
Rails.application.class.configure do
    # Use Pry instead of IRB
    silence_warnings do
      begin
        require 'pry'
        IRB = Pry
      rescue LoadError
      end
    end
  end
CODE
end

## DEVISE SETUP
if yes?("Would you like to install Devise?")
  gem("devise")
  generate("devise:install")
  model_name = ask("What would you like the user model to be called? [user]")
  model_name = "user" if model_name.blank?
  generate("devise", model_name)
  if yes?("Would you like to generate Devise views?")
    generate("devise:views")
  end
end

## CAPISTRANO SETUP
capify!

## DATABASE CONFIG FILES
if yes?("Configure database.yml?")
  remove_file "config/database.yml"
  
  user = ask("Username for database connection to MySQL?")
  pass = ask("Password for database connection to MySQL?")
  
  [["config/database.yml.example", "user", "password"],
   ["config/database.yml", user, pass]].each do |file, user, pass|
    create_file file, "# Configuration file with shared options for #{@app_name}
shared: &shared
  adapter:  mysql2
  host:     localhost
  username: #{user}
  password: #{pass}
  encoding: utf8

master: &master 
  database: #{@app_name}-master

# Any other feature can be defined here
# feature_xyz: &feature_xyz
#   database: #{@app_name}-feature_xyz

development: &development
  <<: *master
  <<: *shared
production:
  <<: *development
staging:
  <<: *development
test:
  <<: *shared
  database: #{@app_name}-test
"
  end

  append_to_file '.gitignore' do
    'config/database.yml'
  end
end

## REMOVE DEFAULT HTML
remove_file "public/index.html"

## RVM CONFIGURATION
if `which rvm` && yes?("Configure rvm?")
  puts `rvm list`
  rvm = ask("Which RVM would you like to use in .rvmrc? Copy it's name")
  puts `rvm gemset list #{rvm}`
  gemset = ask("Which gemset would you like to use in .rvmrc? Copy it's name")

  # we create a .rvmrc file for project
  create_file ".rvmrc" do
    "rvm #{rvm}@#{gemset}"
  end
end

## Pluralization keys - one, few, others
if yes?("Install czech pluralization? (one, few, others)")
  file "config/locales/pluralization/cs.rb", <<-EOF
key = lambda{|n| n==1 ? :one : (n>=2 && n<=4) ? :few : :other}
{:cs => 
  {:i18n => 
    {:keys => [:one, :few, :other], :plural => {:rule => key}}
  }
}
  EOF

  initializer 'i18n.rb', '%w{yml rb}.each do |type|
  Rails.application.config.i18n.load_path += Dir.glob("#{Rails.root}/config/locales/**/*.#{type}")
end
I18n::Backend::Simple.send(:include, I18n::Backend::Pluralization)
'
end

## GIT INITIALIZATION
if yes?("Initialize git?")
  git :init
  git :add => "."
  git :commit => "-m 'Prvni commit'"
end
