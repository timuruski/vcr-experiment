require "net/http"
require "uri"

module HttpHelper
  def get(url)
    request(url) { Net::HTTP::Get.new(url) }
  end

  def post(url, params = nil)
    request(url) {
      request = Net::HTTP::Post.new(url)
      request.body = URI.encode_www_form(params) if params
      request
    }
  end

  private def request(url)
    url = URI.parse(url)
    Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == "https") { |http|
      http.request yield(url)
    }
  end
end

RSpec.configure do |config|
  config.include(HttpHelper, :use_http)
end
