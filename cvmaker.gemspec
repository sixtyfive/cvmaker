# frozen_string_literal: true

require_relative "lib/cvmaker/version"

Gem::Specification.new do |spec|
  spec.name          = "cvmaker"
  spec.version       = CVMaker::VERSION
  spec.authors       = ["J. R. Schmid"]
  spec.email         = ["jrs+git@weitnahbei.de"]

  spec.summary       = "A small collection of commands to create and modify CV and Cover Letters easily with Markdown and LaTeX"
  spec.homepage      = "https://github.com/sixtyfive/cvmaker"
  spec.required_ruby_version = ">= 2.4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "colorize"
  spec.add_dependency "whirly"
  spec.add_dependency "slop"
  spec.add_dependency "iso639"
  spec.add_dependency "tty-editor"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
