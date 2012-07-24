# IglooNET Rails app generator
#
# TODO: add testing frameworks? probably rpsec, cucumber, capybara-webkit, factory_girl
#       ask about gravtastic?
#       ask about paper_trail?
#       split into separate files

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
  create_file 'script/build', <<-CODE#!/usr/bin/env ruby

require 'rubygems'
require 'erb'
require 'fileutils'

template = ERB.new(File.open('config/database.yml.ci.erb') { |file| file.read })
db_host = ARGV[0]
db_user = ARGV[1]
db_pass = ARGV[2]
db_name = ARGV[3]
result = template.result(binding)
File.open("config/database.yml", "w") { |file| file.puts result }  unless File.exists?("config/database.yml")

@result = {}
def set_result(command, output, result)
  @result[command] = {:output => output, :code => result}
end

def format_code(code)
  formated = case code.to_i
    when 0 then 'OK'
    else 'ERROR'
  end
  formated.ljust(5)
end

# necháme posledních 19 měření metrik
data = Dir.glob('tmp/metric_fu/_data/*').sort
(data - data[-19..-1]).each { |f| FileUtils.rm(f) }

# spustíme metriky, migrace a postupně všechny testy, pozapínejte, co se hodí
[
#    'bundle exec metrical 2>&1',
#    'RAILS_ENV=test bundle exec rake db:migrate 2>&1',
#    'Xvfb :99 &',
#    "RAILS_ENV=test bundle exec rspec spec/models/ spec/decorators/ --format html --out \#{ENV['CC_BUILD_ARTIFACTS']}/spec_output.html 2>&1",
#    "DISPLAY=:99 bundle exec cucumber --format html --out \#{ENV['CC_BUILD_ARTIFACTS']}/cucumber.html features/ 2>&1",
].each do |command|
  output = `\#{command}`
  result = $?.exitstatus
  set_result(command, output, result)
end

n = 0
@result.each_pair do |command, result|
  n += 1
  puts "STAGE \#{n}: \#{format_code(result[:code])} (\#{command})"
end

3.times {puts ""}

@result.each_pair do |command, result|
  puts "\#{command} output: \#{result[:output]}" if result[:code].to_i > 0
end

exit(@result.max {|a| a.last[:code]}.last[:code])
CODE

  create_file 'config/database.yml.ci.erb', <<-CODE
shared: &shared
  adapter: mysql2
  username: <%= db_user %>
  password: <%= db_pass %>
  host: <%= db_host %>
  database: <%= db_name %>

test:
  <<: *shared
development:
  <<: *shared
production:
  <<: *shared
CODE
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
