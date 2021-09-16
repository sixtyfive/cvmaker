module CVMaker
  KNOWN_COMMANDS = %w[make edit]

  class Commands
    def initialize(opts)
      @opts = opts
    end

    def make
    end

    def edit
    end

    CVMaker::KNOWN_COMMANDS.each do |command|
      define_singleton_method(command) do |opts|
        new(opts).public_send(command)
      end
    end
  end
end
