require 'bump/tasks'
require 'rspec/core/rake_task'
require 'yard'

YARD::Rake::YardocTask.new(:doc)

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "--tag ~auto_install"
end

RSpec::Core::RakeTask.new(:auto_install_spec) do |t|
  t.rspec_opts = "--tag auto_install"
end

task default: :spec
