require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
end

module BetterCassetteNames
  def self.call(metadata)
    metadata[:vcr] = {} if metadata[:vcr] == true

    metadata[:vcr][:cassette_name] = cassette_name(metadata)
  end

  def self.cassette_name(metadata)
    basename = metadata[:file_path].sub("./spec/", "").chomp(".rb")
    group_path = parent_group_descriptions(metadata).flatten

    Pathname.new(basename).join(*group_path).to_s
  end

  def self.parent_group_descriptions(metadata)
    # metadata[:example_group] is deprecated for example groups
    parent_group = metadata.fetch(:example_group, metadata[:parent_example_group])

    if parent_group
      [parent_group_descriptions(parent_group), metadata[:description]]
    else
      [metadata[:description]]
    end
  end

  class CassettePathReporter
    RSpec::Core::Formatters.register(self, :dump_failures)

    def initialize(output)
      @output = output

      cassette_library_path = VCR.configuration.cassette_library_dir.sub(File.expand_path("."), "")
      @cassette_path_root = ".#{cassette_library_path}/"
    end

    def dump_failures(notification)
      @output.puts "\nUsing VCR cassettes:\n"
      notification.failed_examples.select { |e| e.metadata.dig(:vcr, :cassette_name) }.each_with_index do |example, index|
        cassette_name = example.metadata.dig(:vcr, :cassette_name)
        cassette_path = @cassette_path_root + cassette_name + ".yml"

        @output.puts "  #{index + 1}) #{example.full_description}:"
        @output.puts "     #{cassette_path}"
      end
    end
  end
end

RSpec.configure do |config|
  # config.define_derived_metadata(:vcr) do |metadata|
  #   BetterCassetteNames.call(metadata)
  # end

  # config.before(:suite) do
  #   config.add_formatter BetterCassetteNames::CassettePathReporter
  # end

  config.prepend_before(:example, :vcr) do |example|
    BetterCassetteNames.call(example.metadata)
  end
end
