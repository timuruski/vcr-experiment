require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.default_cassette_options = {persister_options: {downcase_cassette_names: true}}

  config.hook_into :webmock
end

# - Read ENV for mode: development, deployment
# - In development, cassettes:
#   - deploy/* :none
#   - development/* :once
# - In deploy, cassettes:
#   - deploy/* :all

module VcrHelper
  MODE = ENV["VCR_MODE"] || "development"

  DEVELOPMENT = "development".freeze
  DEPLOY = "deploy".freeze

  def self.around
    deploy_mode? ?
      method(:around_deloy) :
      method(:example)
  end

  def self.deploy_mode?
    ENV["VCR_MODE"].to_s.downcase == DEPLOY
  end

  def self.around_development(example)
    fixtures_cassette = "fixtures"
    deploy_cassette = cassette_name(example, prefix: DEPLOY)
    development_cassette = cassette_name(example, prefix: DEVELOPMENT)

    with_cassette(fixtures_cassette, record: none) do
      with_cassette(deploy_cassette, record: :none) do
        with_cassette(development_cassette, cassette_opts(example, record: :once)) do
          example.run; example
        end
      end
    end
  end

  def self.around_deploy(example)
    fixtures_cassette = "fixtures"
    deploy_cassette = cassette_name(example, prefix: DEPLOY)

    with_cassette(example, fixtures_cassette, record: none) do
      with_cassette(example, deploy_cassette, record: :all) do
        example.run
      end
    end
  end

  def self.with_cassette(example, name, opts)
    VCR.insert_cassette(name, opts)

    yield

    # TODO: 
    VCR.eject_cassette(skip_no_unused_interactions_assertion: !!example.exception)
  end

  def self.around_development(example)
    # NOTE Fixture cassette is stored in the root.
    example_cassette = cassette_name(example, prefix: DEPLOY)
    example_cassette = Pathname.new(DEPLOY).join(example_cassette).to_s
    VCR.insert_cassette(cassette_name(example, prefix: DEPLOY), cassette_opts(example, record: :none))



    with_fixtures(:none, prefix: DEVELOPMENT) do
      example_cassette = Pathname.new(DEVELOPMENT).join(cassette_name(example)).to_s
      VCR.insert_cassette(example_cassette, cassette_opts(example))

      example.run

      VCR.eject_cassette(skip_no_unused_interactions_assertion: !!example.exception)
    end
  end

  def self.around_deploy(example)
    with_fixtures(:none, prefix: DEVELOPMENT) do
      example_cassette = Pathname.new(DEVELOPMENT).join(cassette_name(example)).to_s
      VCR.insert_cassette(example_cassette, cassette_opts(example))

      example.run

      VCR.eject_cassette(skip_no_unused_interactions_assertion: !!example.exception)
    end
  end

  def self.with_cassette(name, opts, skip_no_unused_interactions_assertion: true)
    VCR.insert_cassette(name, opts)

    yield

    VCR.eject_cassette(skip_no_unused_interactions_assertion: skip_assert)
  end

  def self.refresh_fixtures(example)
    with_fixtures(:all) do
      example.run
    end
  end

  private_class_method def self.with_fixtures(record_mode, prefix: DEVELOPMENT)
    fixtures_cassette = Pathname.new(prefix).join("fixtures").to_s
    VCR.insert_cassette(fixtures_cassette, record: record_mode)

    yield
  ensure
    VCR.eject_cassette(skip_no_unused_interactions_assertion: true)
  end

  # NOTE prefix should default "development" for path reporter.
  def self.cassette_name(example, prefix: nil)
    path_parts = example.metadata.dig(:vcr, :cassette_name) || build_cassette_name(example)
    File.join([prefix, path_parts].compact)
  end

  private_class_method def self.build_cassette_name(example)
    basename = example.file_path.sub("./spec/", "").chomp(".rb")
    group_path = example.example_group.parent_groups.map(&:description).reverse

    [basename, *group_path, example.description]
  end

  def self.cassette_opts(example, **override_opts)
    opts = example.metadata[:vcr].dup || {}
    opts.delete(:cassette_name)

    opts.merge(override_opts)
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

  config.around(:example, :use_vcr, &VcrHelper.around)

  config.filter_run_excluding :vcr_fixtures
  config.around(:example, :vcr_fixtures) do |example|
    VcrHelper.refresh_fixtures(example)
  end
end
