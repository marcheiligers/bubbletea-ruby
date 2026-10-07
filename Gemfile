# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# gem "bubbles"
gem "harmonica"

gem "ffi", "~> 1.17", platforms: :jruby

# gem "bubbles", path: "../bubbles-ruby"
# gem "glamour", path: "../glamour-ruby"
# gem "harmonica", path: "../harmonica-ruby"
# gem "lipgloss", path: "../lipgloss-ruby"

gem "irb"
gem "logger"
gem "maxitest", "~> 7.0"
gem "rake", "~> 13.0"
gem "rake-compiler", "~> 1.3"
gem "rubocop"

install_if -> { RUBY_ENGINE != "jruby" } do
  gem "glamour"
  gem "lipgloss"
  gem "rake-compiler-dock"
  gem "rbs-inline", "~> 0.13.0"
end
