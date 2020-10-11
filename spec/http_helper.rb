require "net/http"
require "uri"

module HttpHelper
  def get(uri)
    uri = URI.parse(uri)
    Net::HTTP.new(uri.host).request_get(uri.path)
  end

  def post(uri, params = {})
    uri = URI.parse(uri)
    Net::HTTP.new(uri.host).request_post(uri.path, params)
  end
end

RSpec.configure do |config|
  config.include(HttpHelper, :use_http)
end
