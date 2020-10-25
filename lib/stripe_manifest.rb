require "yaml"
require_relative "env"

module StripeManifest
  DEFAULT_PATH = "stripe_manifest.yml"

  def self.sync(manifest_path = DEFAULT_PATH)
    manifest_path = File.expand_path(manifest_path, __dir__)
    Synchronizer.new(manifest_path).sync
  end

  class Synchronizer
    def initialize(manifest_path)
      @manifest_path = manifest_path
      @local_manifest = YAML.safe_load File.read(@manifest_path)
      @stripe_manifest = {}
    end

    def sync
      # 1. Find or create products that are missing in Stripe and record ID to manifest
      # 2. Record ID of products found in Stripe but
      local_products = @local_manifest["products"] ||= {}
      stripe_products = @stripe_manifest["products"] ||= {}
      Stripe::Product.list.auto_paging_each do |object|
        manifest_id = object.metadata["manifest_id"]
        stripe_products[manifest_id] = object unless manifest_id.nil?
      end

      p @manifest_path
      p YAML.dump(@local_manifest)
    end
  end

  private def upsert_product(id, attrs)
    Stripe::Product.retrieve(id)
  rescue Stripe::InvalidRequestError
    Stripe::Product.create(attrs.merge(id: id))
  end

  private def upsert_price(attrs)
    Stripe::Price.list(product: attrs["product"]).auto_paging_each do |price|
      return price if attrs < price.to_hash
    end

    Stripe::Price.create(attrs)
  end
end
