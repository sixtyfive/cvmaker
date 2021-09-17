require 'fileutils'
require 'colorize'
require 'iso639'
require 'tmpdir'
require 'tty-editor'

require_relative 'compiler'

module CVMaker
  KNOWN_COMMANDS = %w[newdoc make edit]
  TEMPLATES = %w[newdoc preamble cv cl_template]
  RES_FILE_TYPES = %w[pdf tif tiff png jpg jpeg gif bmp]

  class Commands
    def initialize(opts)
      @opts = opts
      @opts[:lang] ||= Iso639['English'].alpha2
      raise ArgumentError unless Iso639[@opts[:lang]] 
      raise ArgumentError if @opts.arguments.size != 2
      @main_arg = @opts.arguments[1]
    end

    def filename(tpl_name)
      return tpl_name+'.txt' if tpl_name == 'newdoc'
      tpl_name.gsub(/_template$/,'')+'-'+@opts[:lang]+'.tex.tpl'
    end
    
    def default_template(tpl_name)
      return File.join(File.dirname(__FILE__), '..', '..', 'default_templates', filename(tpl_name))
    end

    def user_template(tpl_name)
      return File.join(Dir.home, '.cvmaker', filename(tpl_name))
    end
    
    def copy_template(from_path, to_path)
      FileUtils.mkdir_p(File.dirname(to_path))
      FileUtils.cp(from_path, to_path)
    end
    
    def newdoc
      path = @main_arg
      (warn "Name must end in .txt!".yellow; exit) unless path.match /\.txt$/
      if File.exist?(path)
        warn "Refusing to overwrite already existing file #{path}!".yellow; exit
      else
        boilerplate = user_template('newdoc')
        boilerplate = default_template('newdoc') unless File.exist?(boilerplate)
        copy_template(boilerplate, path)
        puts "Done! You may now run `cv edit #{path}`!".green
      end
    end

    def make
      @params_file = @main_arg
      raise ArgumentError unless @params_file.match /.*\.txt/
      inpath = File.dirname(@params_file)
      tmpdir = Dir.mktmpdir('cvmaker-')
      begin
        FileUtils.cp(@params_file, File.join(tmpdir,File.basename(@params_file)))
        FileUtils.cp(Dir[File.join(File.dirname(__FILE__),'..','..','moderncv_style','*')], tmpdir)
        @res_files = Dir.glob(
          File.join(inpath, "*.{#{RES_FILE_TYPES.join(',')}}"),
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
        outpath = File.join(inpath, outdir)
        FileUtils.mkdir_p(outpath)
        CVMaker::Compiler.run(tmpdir, File.basename(@params_file), @res_files, @tpl_files)
        outfiles = Dir[File.join(tmpdir,'C{V,L}*.pdf')]
        FileUtils.cp(outfiles, outpath)
        FileUtils.remove_entry(tmpdir)
        puts "All done! Find your freshly made PDFs in #{outpath}!".green
      rescue Errno::ENOENT => e
        file = e.message.split(/-\s+/).last
        warn "Error: no such file: '#{file}'. Got a typo?".red
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
      if TEMPLATES.include? @main_arg
        tpl_name = @main_arg
        @main_arg = user_template(tpl_name)
        copy_template(default_template(tpl_name), @main_arg) unless File.exist?(@main_arg)
      else
        raise ArgumentError unless @main_arg.match /.*\.txt/
      end
      @params_file = File.expand_path(@main_arg)
      unless TTY::Editor.open(@params_file, command: 'gedit')
        # user might not have a favorite editor set
        puts "Sorry, I don't know what your favorite text editor is.\n" \
           + "Please set your EDITOR environment variable to its path\n" \
           + "— or manually edit and save the following file:\n" \
           + "\n" \
           + "  #{@params_file}".light_blue
      end
    end

    CVMaker::KNOWN_COMMANDS.each do |command|
      define_singleton_method(command) do |opts|
        new(opts).public_send(command)
      end
    end
  end
end
