require "bundler/setup"
require "pry"
require "stripe"

Stripe.api_key = ENV.fetch("STRIPE_API_KEY")
