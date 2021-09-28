require 'fileutils'
require 'colorize'
require 'iso639'
require 'tmpdir'
require 'tty-editor'
require 'stringio'

require_relative 'compiler'

module CVMaker
  # all global constants must only be Arrays, because
  # there's some metaprogramming going on which assumes
  # that all non-Array global constants are owned by it
  KNOWN_COMMANDS = %w[newdoc ls make edit]
  TEMPLATES = %w[newdoc preamble cv cl_template config]
  RES_FILE_TYPES = %w[pdf tif tiff png jpg jpeg gif bmp]

  class Commands
    def initialize(opts, config)
      @opts = opts
      @default_lang = config['default_lang']
      @opts[:lang] ||= @default_lang
      unless Iso639[@opts[:lang]] 
        warn "Oops, #{@opts[:lang]} is no valid ISO-639-2 language code!".red; exit
      end
      @main_arg = @opts.arguments[1] if @opts.arguments.size == 2
      @dot_dir = config['config_path']
      @config_file = config['config_file']
      @docs_path = config['default_docs_path']
      @attachments_dir = config['attachments_dir']
      @editor = config['default_editor']
      @res_path = config['res_path']
    end

    def filename(tpl_name, lang=nil)
      lang ||= @opts[:lang]
      return tpl_name+'.txt' if tpl_name == 'newdoc'
      return 'cvmaker.conf' if tpl_name == 'config'
      tpl_name.gsub(/_template$/,'')+'-'+lang+'.tex.tpl'
    end

    def default_template(tpl_name, lang=nil)
      lang ||= @opts[:lang]
      return File.join(File.dirname(__FILE__), '..', '..', 'default_templates', filename(tpl_name, lang))
    end

    def user_template(tpl_name)
      return File.join(@dot_dir, filename(tpl_name))
    end
    
    def copy_template(from_path, to_path)
      FileUtils.mkdir_p(File.dirname(to_path))
      FileUtils.cp(from_path, to_path)
    end

    def ls
      puts Dir[File.join(@docs_path,'*.txt'), File.join(@docs_path,'*','*.txt')].map{|f| File.basename(f)}.sort.join("\n")
    end
    
    def newdoc
      raise ArgumentError unless @main_arg
      name = File.basename(@main_arg, '.txt')
      dir = File.dirname(@main_arg)
      dir = @docs_path unless dir.include? '/'
      path = File.expand_path(File.join(dir, name+'.txt'))
      if File.exist?(path)
        warn "Refusing to overwrite already existing file #{path}!".yellow; exit
      else
        boilerplate = user_template('newdoc')
        boilerplate = default_template('newdoc') unless File.exist?(boilerplate)
        copy_template(boilerplate, path)
        puts "Done! You may now run `cv edit #{name}`!".green
      end
    end

    def find_params_file(arg)
      name = File.basename(arg, '.txt')
      dirs = [@docs_path, File.join(@docs_path,name), '.', File.join('.',name)]
      params_file = nil
      dirs.each{|d| f=File.join(d,name+'.txt'); params_file=f if File.exist?(f)}
      (warn "Whoops, can't find a file called \"#{arg}\". Got a typo?".yellow; exit) unless params_file
      File.expand_path(params_file)
    end

    def make
      raise ArgumentError unless @main_arg
      params_file = find_params_file(@main_arg)
      inpath = File.dirname(params_file)
      tmpdir = Dir.mktmpdir('cvmaker-')
      begin
        FileUtils.cp(params_file, File.join(tmpdir,File.basename(params_file)))
        FileUtils.cp(Dir[File.join(File.dirname(__FILE__),'..','..','moderncv_style','*')], tmpdir)
        @res_files = Dir.glob(
          File.join(@res_path, "*.{#{RES_FILE_TYPES.join(',')}}"),
          File::FNM_CASEFOLD).map{|r| # upper/lowercase mustn't matter here
            FileUtils.cp(r, File.join(tmpdir,File.basename(r)))
            File.basename(r)}
        @tpl_files = TEMPLATES.map{|t|
          u = user_template(t)
          d = default_template(t)
          t = File.exist?(u) ? u : d
          FileUtils.cp(t, File.join(tmpdir, File.basename(t)))
          File.basename(t)}
        outdir = File.basename(params_file,'.txt')
        # on first go-around, put output files into a sub-directory by the name of the input file
        outpath = File.join(inpath, outdir)
        # oh! but this one isn't being compiled the first time; it was already stowed away...
        outpath = inpath if outdir == inpath.split('/').last
        # either way, make sure the path exists
        FileUtils.mkdir_p(outpath)
        CVMaker::Compiler.run(tmpdir, File.basename(params_file), @res_files, @tpl_files)
        outfiles = Dir[File.join(tmpdir,'C{V,L}*.pdf')]
        FileUtils.cp(outfiles, outpath)
        # do the house cleaning
        FileUtils.remove_entry(tmpdir)
        if @docs_path == File.dirname(params_file) and Dir.exist?(outpath)
          FileUtils.mv(params_file, outpath)
          puts "  (#{File.basename(params_file)} moved to #{outpath})"
        end
        puts "All done! Find your freshly made PDFs in #{outpath}!".green
      rescue Errno::ENOENT => e
        file = e.message.split(/-\s+/).last
        warn "Error: no such file: \"#{file}\". Got a typo?".red
      rescue RuntimeError => e
        warn e.message.red
        warn "Often there'll just be a typo in one of your templates or the .txt file..."
      rescue Exception => e
        warn ("Error: something went wrong. The message was:" \
            + "  #{e.message.gsub(/\n/,"\n  ")}").red \
            + "If you're, like, really good with troubleshooting things, maybe check out #{tmpdir}?" \
            + "Otherwise, please shoot us an Issue at "+"https://github.com/sixtyfive/cvmaker/issues!".light_blue
      ensure
        # no need for an empty directory to be there
        FileUtils.rmdir(outpath) if Dir.empty?(outpath)
      end
    end
    
    def edit
      raise ArgumentError unless @main_arg
      if TEMPLATES.include? @main_arg
        file = user_template(@main_arg)
        if @opts[:lang] != @default_lang and !File.exist?(default_template(@main_arg))
          # this is in case we don't supply a default template in the chosen language 
          copy_template(default_template(@main_arg,@default_lang), default_template(@main_arg,@opts[:lang]))
        end
        copy_template(default_template(@main_arg), file) unless File.exist?(file)
      else
        file = find_params_file(@main_arg)
      end
      @editor = 'nano' if ENV['DISPLAY'].to_s.empty?
      unless TTY::Editor.open(file.strip, command: @editor)
        # user might not have a favorite editor set
        puts "Sorry, I couldn't launch the '#{@editor}' editor.\n" \
           + "Please change #{@config_file} accordingly or\n" \
           + "manually edit and save the following file:\n" \
           + "\n" \
           + "  #{file}".light_blue
      end
    end

    # called by CVMaker::CLI
    CVMaker::KNOWN_COMMANDS.each do |command|
      define_singleton_method(command) do |opts,config|
        new(opts,config).public_send(command)
      end
    end
  end
end
