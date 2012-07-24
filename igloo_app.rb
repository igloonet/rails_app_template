# IglooNET Rails app generator
#
# TODO: run gem generators after bundle install! and setting rvm
#       add testing frameworks? probably rpsec, cucumber, capybara-webkit, factory_girl
#       ask about gravtastic?
#       ask about paper_trail?
#       improve database.yml generating (erb in separate file)
#       improve cs.rb - use 1.9 hash syntax
#       wait for openssl fix so we get rid of VERIFY_NONE mode, which brings potential security risk

require 'open-uri'
SOURCE = 'https://raw.github.com/igloonet/rails_app_template/master/templates/'
def download(filename)
  open(SOURCE + filename, :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE).read
end

## EVERGREEN GEMS SETUP
# gem "rein" - causes weird errors on startup (class mismatch)
gem "mysql2"
# rails 3.1 requirement, may be removed in future
gem 'execjs'
# rails 3.1 requirement, may be removed in future
gem 'therubyracer'


## METRICS?
if yes?("Do you want to use metrics with metrical?")
  gem("metrical", :group => :development)
end

if yes?("Prepare for cc.rb integration?")
  create_file 'script/build', download('build')
  create_file 'config/database.yml.ci.erb', download('database.yml.ci.erb')
end

# ActiveRecord plugins
if yes?("Use kaminari as paginator?")
  gem "kaminari"
  generate "kaminari:config"
end
if yes?("Use squeel for better AR conditions syntax?")
  gem "squeel"
  initializer 'squeel.rb', download('squeel.rb')
end
if yes?("Use ransack for easy filtering and searching?")
  gem "ransack"
end

## PRY INTEGRATION
if yes?("Use Pry instead of IRB?")
  gem "pry"
  initializer 'pry.rb', download('pry.rb')
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
  file "config/locales/pluralization/cs.rb", download('cs.rb')
  initializer 'i18n.rb', download('i18n.rb')
end

## CANCAN INSTALLATION
if yes?("Use cancan for authorisation?")
  gem "cancan"
  generate "cancan:ability"
end

## WHENEVER
if yes?("Use whenever for cron management?")
  gem "whenever", :require => false
  `wheneverize .`
end

## GIT INITIALIZATION
if yes?("Initialize git?")
  git :init
  git :add => "."
  git :commit => "-m 'Prvni commit'"
end
