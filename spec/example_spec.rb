require "spec_helper"

RSpec.describe "http recording", :use_http do
  context "when use_vcr is enabled", :use_vcr do
    it "works" do
      result = get("https://httpbin.org/get?id=123")

      expect(result.code).to eq "200"
    end

    describe "when there is a group" do
      it "works" do
        result = get("https://httpbin.org/get?id=123")

        expect(result.code).to eq "200"
      end
    end

    describe "when there is group" do
      context "and another group nested inside" do
        it "works" do
          result = get("https://httpbin.org/get?id=123")

          expect(result.code).to eq "200"
        end
      end
    end
  end

  describe "when use_vcr is disabled" do
    it "works" do
      expect {
        get("https://httpbin.org/get?id=123")
      }.to raise_error(VCR::Errors::UnhandledHTTPRequestError)
    end
  end
end
