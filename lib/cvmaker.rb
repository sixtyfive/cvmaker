# frozen_string_literal: true

require_relative 'cvmaker/version'
require_relative 'cvmaker/commands'

require 'slop'

module CVMaker
  class Error < StandardError; end
    
  class CLI
    def print_usage; puts @opts; exit; end

    def initialize
      slop_config = Slop::Options.new
      slop_config.banner = "Usage: cv <command> [options]\n\n" \
                         + "  available commands:\n\n" \
                         + "  - make <path to .txt file>\n" \
                         + "  - edit <preamble|cv_template|cl_template> or <path to .txt file>"
      slop_parser = Slop::Parser.new(slop_config)
      @opts = slop_parser.parse(ARGV)
      print_usage unless @opts.arguments.any?
      @command = @opts.arguments.first
      print_usage unless CVMaker::KNOWN_COMMANDS.include? @command
      CVMaker::Commands.public_send(@command, @opts)
    end

    def self.start; new; end
  end
end
