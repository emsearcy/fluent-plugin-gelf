# encoding: utf-8
require "bundler/gem_tasks"

require 'rake/testtask'
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = Dir["test/**/test_*.rb"].sort
  t.verbose = true
end
task :default => :test
