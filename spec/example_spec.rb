require "spec_helper"

RSpec.describe "HTTP recording", :use_http do
  context "when use_vcr is enabled", :use_vcr do
    it "gets a successful response" do
      result = get("https://httpbin.org/get?id=123")

      expect(result.code).to eq "400"
    end

    describe "when there is a group" do
      it "gets a successful response" do
        result = get("https://httpbin.org/get?id=123")

        expect(result.code).to eq "200"
      end
    end

    describe "when there is group" do
      context "and another group nested inside" do
        it "gets a successful response" do
          result = get("https://httpbin.org/get?id=123")

          expect(result.code).to eq "200"
        end
      end
    end
  end

  context "when use_vcr is disabled" do
    it "raises an unhandled request error" do
      expect {
        get("https://httpbin.org/get?id=123")
      }.to raise_error(VCR::Errors::UnhandledHTTPRequestError)
    end
  end

  context "with fixtures", :use_vcr do
    it "uses the fixture" do
      get("https://httpbin.org/get?user_id=123")
      get("https://httpbin.org/get?article_id=123")

      result =get("https://httpbin.org/get?id=abc")

      expect(result.code).to eq "200"
    end
  end
end
