require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
end

class VCRHelper
  attr_reader :example, :cassette_name
  def initialize(example)
    @example = example
    @cassette_name = build_cassette_name

    example.metadata[:vcr_cassette_path] = VCR.configuration.cassette_library_dir + "/" + cassette_name + ".yml"
  end

  def run
    VCR.use_cassette("fixtures") do
      VCR.use_cassette(cassette_name, cassette_opts) do
        example.metadata[:vcr_cassette_list] = VCR.cassettes.map(&:name)
        example.run
      end
    end
  end

  private def build_cassette_name
    basename = example.file_path.sub("./spec/", "").chomp(".rb")
    group_path = example.example_group.parent_groups.reverse.map { |group| clean_filename(group.description) }.join("/")
    filename = clean_filename(example.description)

    Pathname.new(basename).join(group_path, filename).to_s
  end

  private def clean_filename(str)
    str.downcase.gsub(/\s+/, "-").gsub(/["']/, "")
  end

  private def cassette_opts
    {}
  end

  class CassettePathFormatter
    RSpec::Core::Formatters.register(self, :dump_failures)

    def initialize(output)
      @failed_examples = []
      @output = output
    end

    def dump_failures(notification)
      @output.puts "\nUsing VCR cassettes:\n"

      notification.failed_examples.select { |e| e.metadata[:use_vcr] }.each_with_index do |example, index|
        @output.puts "  #{index + 1}) #{example.full_description}:"
        example.metadata[:vcr_cassette_list].each do |cassette_name|
          cassette_path = "spec/vcr_cassettes/" + cassette_name + ".yml"
          @output.puts "     #{cassette_path}"
        end
      end
    end
  end
end


RSpec.configure do |config|
  config.before(:suite) do
    config.add_formatter VCRHelper::CassettePathFormatter
  end

  config.around(:example, :use_vcr) do |example|
    VCRHelper.new(example).run
  end
end
