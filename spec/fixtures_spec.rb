require "spec_helper"

# NOTE This spec is used to generate fixtures.
# rspec -t vcr_fixtures
RSpec.describe "Stripe fixtures", :vcr_fixtures, :use_http do
  specify "standard Widget" do
    Stripe::Product.retrieve("
  end
  specify "user fixture" do
    get("https://httpbin.org/get?user_id=123")
  end

  specify "article fixture" do
    get("https://httpbin.org/get?article_id=123")
  end
end
