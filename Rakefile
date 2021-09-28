# frozen_string_literal: true

require "bundler/gem_tasks"
task default: %i[]

desc "commit, push, bump, commit, push, release, all in one fell swoocp"
task :new_minor_release do
  system('git commit -a -m "new release"')
  system('git push')
  ver_file = 'lib/cvmaker/version.rb'
  ver_code = File.read(ver_file)
  version = ver_code.scan(/[\d\.]+/).first.split('.').map(&:to_i)
  version[-1] = version[-1] + 1
  File.write(ver_file, ver_code.gsub(/[\d\.]+/, version)) 
  system('git commit -a -m "bumping"')
  system('git push')
  system('rake release')
end
