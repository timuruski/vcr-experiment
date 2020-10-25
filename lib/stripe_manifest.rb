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
      @local_manifest = YAML.load File.read(@manifest_path)
    end

    # TODO Update Stripe object if manifest changes.
    def sync
      # Products
      stripe_products = load_manifest(Stripe::Product)
      local_products = @local_manifest["products"] ||= {}
      local_products.each do |manifest_id, attrs|
        stripe_obj = stripe_products[manifest_id]

        if stripe_obj.nil?
          product_attrs = create_attrs(manifest_id, attrs)
          stripe_obj = Stripe::Product.create(product_attrs)
        end

        warn "Replacing #{attrs["stripe_id"]}" if attrs["stripe_id"] != stripe_obj.id
        attrs["stripe_id"] = stripe_obj.id
      end

      # Prices
      stripe_prices = load_manifest(Stripe::Price)
      local_prices = @local_manifest["prices"] ||= {}
      local_prices.each do |manifest_id, attrs|
        stripe_obj = stripe_prices[manifest_id]

        if stripe_obj.nil?
          price_attrs = create_attrs(manifest_id, attrs)
          price_attrs["product"] = local_products[attrs["product"]]["stripe_id"]
          stripe_obj = Stripe::Price.create(price_attrs)
        end

        warn "Replacing #{attrs["stripe_id"]}" if attrs["stripe_id"] != stripe_obj.id
        attrs["stripe_id"] = stripe_obj.id
      end

      File.write(@manifest_path, YAML.dump(@local_manifest))
    end

    private def load_manifest(stripe_object)
      stripe_object.list.auto_paging_each.with_object({}) do |object, manifest|
        if manifest_id = object.metadata["manifest_id"]
          manifest[manifest_id] = object
        end
      end
    end

    private def create_attrs(manifest_id, attrs)
      attrs.dup
        .merge(metadata: {manifest_id: manifest_id})
        .delete_if { |k,_| k == "stripe_id" }
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
