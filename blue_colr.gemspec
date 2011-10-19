# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name        = "blue_colr"
  s.version     = '0.1.4'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Mladen Jablanovic"]
  s.email       = ["jablan@radioni.ca"]
  s.homepage    = "http://github.com/jablan/blue_colr"
  s.summary     = "Database based process launcher"
  s.description = "Blue_colr provides simple DSL to enqueue processes in given order, using database table as a queue, and a deamon to run them"

#  s.required_rubygems_version = ">= 1.3.6"
#  s.rubyforge_project         = "blue_colr"

  s.add_dependency "sequel"

  s.files        = Dir.glob("{bin,lib}/**/*") + %w(README.rdoc)
  s.executables  = ['bluecolrd', 'bcrun']
  s.require_path = 'lib'
end
