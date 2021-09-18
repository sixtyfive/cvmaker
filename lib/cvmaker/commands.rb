require 'fileutils'
require 'colorize'
require 'iso639'
require 'tmpdir'
require 'tty-editor'
require 'parseconfig'

require_relative 'compiler'

module CVMaker
  # all global constants must only be Arrays, because
  # there's some metaprogramming going on which assumes
  # that all non-Array global constants are owned by it
  KNOWN_COMMANDS = %w[newdoc ls make edit]
  TEMPLATES = %w[newdoc preamble cv cl_template config]
  RES_FILE_TYPES = %w[pdf tif tiff png jpg jpeg gif bmp]

  class Commands
    def initialize(opts)
      @opts = opts
      @opts[:lang] ||= Iso639['English'].alpha2
      raise ArgumentError unless Iso639[@opts[:lang]] 
      @dot_dir = File.join(Dir.home, '.cvmaker')
      @config_file = File.join(@dot_dir, filename('config'))
      FileUtils.touch(@config_file)
      @config = ParseConfig.new(@config_file)
      read_or_init_config_file
      @res_path = File.join(@docs_path, @attachments_dir)
      @main_arg = @opts.arguments[1] if @opts.arguments.size == 2
    end

    def ask_for_docs_path
      path = default_path = File.join(Dir.home, 'Applications')
      puts "It seems this is your first run, or perhaps you're upgrading from an older version."
      puts "I just have one quick question for you: where would you like your documents to be stored by default?"
      puts "Please type a full path or hit <Enter> to accept the default."
      loop do
        accepted = false
        print "\n  [#{default_path.light_blue}]: "
        path = STDIN.gets.chomp
        if Dir.exist? path
          accepted = true; puts
        else
          print "\n#{path} does not exist yet. Okay to create (#{'y'.light_blue}) or not (#{'n'.light_blue})? "
          (FileUtils.mkdir_p(path); accepted = true) if STDIN.gets.chomp == 'y'
        end
        (puts "Okay, saving #{path} as default document storage!\n"; break) if accepted
      end
      path
    end

    def read_or_init_config_file
      loop do
        @docs_path = @config['default_docs_path']
        break if @docs_path
        @config.add('default_docs_path', ask_for_docs_path) unless @docs_path
      end
      loop do
        @attachments_dir = @config['attachments_dir']
        break if @attachments_dir
        @config.add('attachments_dir', 'Attachments') unless @attachments_dir
      end
      loop do
        @editor = @config['default_editor']
        break if @editor
        @config.add('default_editor', 'gedit') unless @editor
      end
      @config.write(File.open(@config_file, 'w'))
    end

    def filename(tpl_name)
      return tpl_name+'.txt' if tpl_name == 'newdoc'
      return 'cvmaker.conf' if tpl_name == 'config'
      tpl_name.gsub(/_template$/,'')+'-'+@opts[:lang]+'.tex.tpl'
    end

    def default_template(tpl_name)
      return File.join(File.dirname(__FILE__), '..', '..', 'default_templates', filename(tpl_name))
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
      @params_file = nil
      dirs.each{|d| f=File.join(d,name+'.txt'); @params_file=f if File.exist?(f)}
      (warn "Whoops, can't find a file called \"#{arg}\". Got a typo?".yellow; exit) unless @params_file
      @params_file = File.expand_path(@params_file)
    end

    def make
      raise ArgumentError unless @main_arg
      @params_file = find_params_file(@main_arg)
      inpath = File.dirname(@params_file)
      tmpdir = Dir.mktmpdir('cvmaker-')
      begin
        FileUtils.cp(@params_file, File.join(tmpdir,File.basename(@params_file)))
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
        outdir = File.basename(@params_file,'.txt')
        # on first go-around, put output files into a sub-directory by the name of the input file
        outpath = File.join(inpath, outdir)
        # oh! but this one isn't being compiled the first time; it was already stowed away...
        outpath = inpath if outdir == inpath.split('/').last
        # either way, make sure the path exists
        FileUtils.mkdir_p(outpath)
        CVMaker::Compiler.run(tmpdir, File.basename(@params_file), @res_files, @tpl_files)
        outfiles = Dir[File.join(tmpdir,'C{V,L}*.pdf')]
        FileUtils.cp(outfiles, outpath)
        FileUtils.remove_entry(tmpdir)
        FileUtils.rmdir(outpath) if Dir.empty?(outpath)
        puts "All done! Find your freshly made PDFs in #{outpath}!".green
        # do some house cleaning
        if @docs_path == File.dirname(@params_file) and Dir.exist?(outpath)
          FileUtils.mv(@params_file, outpath)
          puts "  (#{File.basename(@params_file)} moved to #{outpath})"
        end
      rescue Errno::ENOENT => e
        file = e.message.split(/-\s+/).last
        warn "Error: no such file: \"#{file}\". Got a typo?".red
      rescue RuntimeError => e
        warn e.message.red
        warn "Often there'll just be a typo in one of your templates or the .txt file..."
      rescue Exception => e
        warn ("Error: something went wrong. The message was:" \
            + "  #{e.message.gsub(/\n/,"\n  ")}").red
            + "If you're, like, really good with troubleshooting things, maybe check #{tmpdir} out?"
      end
    end
    
    def edit
      raise ArgumentError unless @main_arg
      if TEMPLATES.include? @main_arg
        @params_file = user_template(@main_arg)
        copy_template(default_template(@main_arg), @params_file) unless File.exist?(@params_file)
      else
        @params_file = find_params_file(@main_arg)
      end
      @editor = 'nano' if ENV['DISPLAY'].to_s.empty?
      unless TTY::Editor.open(@params_file, command: @editor)
        # user might not have a favorite editor set
        puts "Sorry, I couldn't launch the '#{@editor}' editor.\n" \
           + "Please change #{@config_file} accordingly or\n" \
           + "manually edit and save the following file:\n" \
           + "\n" \
           + "  #{@params_file}".light_blue
      end
    end

    # called by CVMaker::CLI
    CVMaker::KNOWN_COMMANDS.each do |command|
      define_singleton_method(command) do |opts|
        new(opts).public_send(command)
      end
    end
  end
end
