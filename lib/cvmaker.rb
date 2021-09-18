# frozen_string_literal: true

require_relative 'cvmaker/version'
require_relative 'cvmaker/commands'

require 'slop'

module CVMaker
  class CLI
    def print_usage; puts @opts; exit; end

    def initialize
      opts = Slop::Options.new
      opts.banner = "Usage: "+"cv".light_blue+" <command> [options]\n\n" \
                  + "  available commands:\n\n" \
                  + "  newdoc <name or path>".light_blue+" (will create a new file for you to fill out)\n" \
                  + "  ls".light_blue+ "                    (show files currently in default storage)\n" \
                  + "  make   <name or path>".light_blue+" (will read a file such as created by 'new')\n" \
                  + "  edit   <newdoc|cv|cl_template|preamble|config>".light_blue+" (all are LaTeX) or "+"<path to .txt file>".light_blue
      opts.separator "\n  options:\n"
      opts.string '-l', '--lang', 'language of template to edit, or of template to use for making the PDF(s)'
      opts.separator "                languages should be specified in ISO-639-2, "+"e.g. 'en', 'hi', 'jbo', etc.".light_blue
      opts.separator "                (the default language is English - or the .txt's LANG option if present)\n"
      opts.separator "  Output PDF(s) will be written to a new folder, i.e."
      opts.separator "  for a CL called Rekall.txt, you'll get Rekall/*.pdf\n"
      @opts = Slop::Parser.new(opts).parse(ARGV)
      print_usage unless @opts.arguments.any?
      @command = @opts.arguments.first
      (warn "Error: unknown command '#{@command}'!".red; print_usage) unless CVMaker::KNOWN_COMMANDS.include? @command
      begin
        CVMaker::Commands.public_send(@command, @opts)
      rescue ArgumentError
        print_usage
      end
    end

    def self.start; new; end
  end
end
