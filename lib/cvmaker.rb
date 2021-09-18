# frozen_string_literal: true

require_relative 'cvmaker/version'
require_relative 'cvmaker/commands'

require 'slop'
require 'parseconfig'
require 'iso639'

module CVMaker
  class CLI
    def print_usage; puts @opts; exit; end
    def print_version; puts VERSION; exit; end

    def initialize
      load_config_file
      lang_name = Iso639[@config['default_lang']].english_names.first
      config_file = @config['config_file'].gsub(Dir.home, '~')
      opts = Slop::Options.new
      opts.banner = "Usage: "+"cv".light_blue+" <command> [options] 🐿️\n\n" \
                  + "  available commands:\n\n" \
                  + "  newdoc <name or path>".light_blue+" (will create a new file for you to fill out)\n" \
                  + "  ls".light_blue+ "                    (show files currently in default storage)\n" \
                  + "  make   <name or path>".light_blue+" (will read a file such as created by 'new')\n" \
                  + "  edit".light_blue+"   " \
                    + "<name or path>".light_blue+" or " \
                    + "newdoc".light_blue+" or " \
                    + "cv|cl_template|preamble".light_blue \
                    + " (all are LaTeX) or " \
                    + "config".light_blue
      opts.separator "\n  options:\n"
      opts.string '-l', '--lang', 'language of template to edit, or of template to use for making the PDF(s)'
      opts.separator "                   languages should be specified in ISO-639-2, "+"e.g. 'en', 'hi', 'jbo', etc.".light_blue
      opts.separator "                   (the default is #{lang_name} and can be changed in #{config_file})"
      opts.bool '-v', '--version', "print cvmaker version and exit immediately\n"
      opts.separator "  Output PDF(s) will be written to a new folder, i.e."
      opts.separator "  for a CL called Rekall.txt, you'll get Rekall/*.pdf\n"
      @opts = Slop::Parser.new(opts).parse(ARGV)
      print_version if @opts[:version]
      print_usage unless @opts.arguments.any?
      @command = @opts.arguments.first
      (warn "Error: unknown command '#{@command}'!".red; print_usage) unless CVMaker::KNOWN_COMMANDS.include? @command
      begin
        CVMaker::Commands.public_send(@command, @opts, @config)
      rescue ArgumentError
        print_usage
      end
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

    def load_config_file
      dot_dir = File.join(Dir.home, '.cvmaker')
      config_file = File.join(dot_dir, 'cvmaker.conf')
      FileUtils.touch(config_file)
      old_config_string = File.read(config_file).strip
      @config = ParseConfig.new(config_file)
      @config.add('config_path', dot_dir)
      @config.add('config_file', config_file)
      docs_path = ''
      loop do
        docs_path = @config['default_docs_path']
        break if docs_path
        @config.add('default_docs_path', ask_for_docs_path) unless docs_path
      end
      attachments_dir = ''
      loop do
        attachments_dir = @config['attachments_dir']
        break if attachments_dir
        @config.add('attachments_dir', 'Attachments') unless attachments_dir
      end
      editor = ''
      loop do
        editor = @config['default_editor']
        break if editor
        @config.add('default_editor', 'gedit') unless editor
      end
      lang = ''
      loop do
        lang = @config['default_lang']
        break if lang
        @config.add('default_lang', Iso639['English'].alpha2)
      end
      res_path = File.join(docs_path, attachments_dir)
      @config.add('res_path', res_path)
      new_config = StringIO.new
      @config.write(new_config)
      if new_config.string.strip != old_config_string
        File.write(config_file, new_config.string.strip) 
      end
    end

    def self.start; new; end
  end
end
