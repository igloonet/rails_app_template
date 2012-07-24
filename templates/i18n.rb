%w{yml rb}.each do |type|
  Rails.application.config.i18n.load_path += Dir.glob("#{Rails.root}/config/locales/**/*.#{type}")
end
I18n::Backend::Simple.send(:include, I18n::Backend::Pluralization)
