require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.default_cassette_options = { :persister_options => { :downcase_cassette_names => true } }

  config.hook_into :webmock
end

module VcrHelper
  def self.fixtures(example)
    VCR.insert_cassette("fixtures", record: :all)

    example.run

    VCR.eject_cassette(skip_no_unused_interactions_assertion: !!example.exception)
  end

  def self.around(example)
    VCR.insert_cassette("fixtures", record: :none)
    VCR.insert_cassette(cassette_name(example), cassette_opts(example))

    example.run

    VCR.eject_cassette(skip_no_unused_interactions_assertion: !!example.exception)
    VCR.eject_cassette(skip_no_unused_interactions_assertion: true)
  end

  def self.cassette_name(example)
    example.metadata.dig(:vcr, :cassette_name) || build_cassette_name(example.metadata)
  end

  def self.cassette_opts(example)
    opts = example.metadata[:vcr].dup || {}
    opts.delete(:cassette_name)

    opts
  end

  private_class_method def self.build_cassette_name(metadata)
    basename = metadata[:file_path].sub("./spec/", "").chomp(".rb")
    group_path = parent_group_descriptions(metadata).flatten

    Pathname.new(basename).join(*group_path).to_s
  end

  private_class_method def self.parent_group_descriptions(metadata)
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
      notification.failed_examples.select { |e| e.metadata[:use_vcr] }.each_with_index do |example, index|
        @output.puts "  #{index + 1}) #{example.full_description}:"
        @output.puts "     #{cassette_path(example)}"
      end
    end

    private def cassette_path(example)
      cassette_name = VcrHelper.cassette_name(example)
      cassette_name = VCR::Cassette::Persisters::FileSystem.send(:sanitized_file_name_from, cassette_name)
      @cassette_path_root + cassette_name + ".yml"
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    config.add_formatter VcrHelper::CassettePathReporter
  end

  config.around(:example, :use_vcr) do |example|
    VcrHelper.around(example)
  end

  config.filter_run_excluding :vcr_fixtures
  config.around(:example, :vcr_fixtures) do |example|
    VcrHelper.fixtures(example)
  end
end
