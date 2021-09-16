# Cross-platform way of finding an executable in the $PATH.
#   which('ruby') #=> /usr/bin/ruby
# https://stackoverflow.com/a/5471032/5354137
def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end
  nil
end
