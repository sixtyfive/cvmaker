require 'colorize'

require_relative 'which'

module CVMaker
  class Compiler
    def initialize(dir, params_file, res_files, tpl_files)
      @dir = dir
      params_file = File.join(@dir, params_file)
      puts "Compiling with parameters from #{params_file}".light_black
      res_files = res_files.map{|f| File.join(@dir, f)}
      tpl_files = tpl_files.map{|f| File.join(@dir, f)}
      fcontents = File.read(params_file)
      fcontents += '"' unless fcontents.strip.chars.last == '"' # to guard against user error
      eval(fcontents) # this will put a bunch of new all-uppercase constants on the module scope...
      @params = Module.constants.filter{|c| c.match /(OWN|ADDRESSEE|CL)_/}.map{|var| ["VAR_#{var}", eval(var.to_s)]}.sort.to_h # ... which are being handled here
      @attachments = @params['VAR_CL_ATTACHMENTS'].split(',').map{|a| a.gsub(/'/, '').gsub(/\w+/){|w| w.capitalize}.gsub(/[\s\.]+/, '')+'.pdf'}[1..-1].map{|a|
        File.exist?(File.join(@dir,a)) ? puts("#{a} found".light_black) : warn("Warning: referenced attachment file '#{a}' not found!".yellow)
        "\\includepdf[pages=-]{#{File.join(@dir,a)}}"}
      @templates = tpl_files.map{|f| [File.basename(f,'.tex.tpl').gsub(/-\w+$/,'').to_sym, File.read(f)]}.to_h
      @texsource = {
        CL_only: [
          @templates[:preamble],
          '\begin{document}',
          '\clearpage',
          @templates[:cl],
          '\end{document}'].join("\n\n"),
        CV_only: [
          @templates[:preamble],
          '\begin{document}',
          '\clearpage',
          @templates[:cv],
          '\end{document}'].join("\n\n"),
        CL_CV_attachments: [
          @templates[:preamble],
          '\begin{document}',
          '\clearpage',
          @templates[:cl],
          '\newpage',
          @templates[:cv],
          @attachments.join("\n"),
          '\end{document}'].join("\n\n")
      }
    end

    def apply_subst(str)
      @params.each{|var,val| str = str.gsub(var, val) if val.class == String}; str
    end; private :apply_subst

    def compile
      @texsource.each do |name,contents|
        f = File.join(@dir, name.to_s+'.tex')
        File.write(f, apply_subst(contents))
        puts "#{f} written".light_black
        if cmd = which('xelatex')
          dirchange = "cd #{@dir};"
          opts = ["-halt-on-error"]
          redirect = '>/dev/null'
          retval = system([dirchange, cmd, opts, f, redirect].flatten.join(' '))
          pdf = f.gsub(/\.tex$/,'.pdf')
          if retval and File.exist?(pdf)
            puts "#{pdf} written".light_black
          else 
            log = f.gsub(/\.tex$/,'.log')
            raise RuntimeError, "XeLaTeX was unable to compile #{f}.\nSee #{log} for details."
          end
        else
          warn ("Error: no 'xelatex' command found." \
              + "Please install TeX Live and try again.").red
          exit
        end
      end
    end

    def self.run(dir, params_file, res_files, tpl_files)
      new(dir, params_file, res_files, tpl_files).compile
    end
  end
end
