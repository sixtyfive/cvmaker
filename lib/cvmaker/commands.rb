require 'fileutils'
require 'colorize'
require 'iso639'
require 'tmpdir'
require 'tty-editor'

require_relative 'compiler'

module CVMaker
  KNOWN_COMMANDS = %w[make edit]
  TEMPLATES = %w[preamble cv cl_template]
  RES_FILE_TYPES = %w[pdf tif tiff png jpg jpeg gif bmp]

  class Commands
    def initialize(opts)
      @opts = opts
      @opts[:lang] ||= Iso639['English'].alpha2
      raise ArgumentError unless Iso639[@opts[:lang]] 
      raise ArgumentError if @opts.arguments.size != 2
      @params_file = @opts.arguments[1]
    end

    def filename(tpl_name)
      tpl_name.gsub(/_template$/,'')+'-'+@opts[:lang]+'.tex.tpl'
    end
    
    def default_template(tpl_name)
      return File.join(File.dirname(__FILE__), '..', '..', 'default_templates', filename(tpl_name))
    end

    def user_template(tpl_name)
      return File.join(Dir.home, '.cvmaker', filename(tpl_name))
    end

    def make
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
    
    def copy_template(from_path, to_path)
      FileUtils.mkdir_p(File.dirname(to_path))
      FileUtils.cp(from_path, to_path)
    end

    def edit
      if TEMPLATES.include? @params_file
        tpl_name = @params_file
        @params_file = user_template(tpl_name)
        copy_template(default_template(tpl_name), @params_file) unless File.exist?(@params_file)
      else
        raise ArgumentError unless @params_file.match /.*\.txt/
      end
      @params_file = File.expand_path(@params_file)
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
