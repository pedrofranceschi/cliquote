require 'rubygems'
require 'net/http'
require 'multi_json'

def get_quotes
  MultiJson.load(Net::HTTP.get_response('clearquot.es', '/quotes.json').body)
end

def get_random_quote(quotes)
  quotes['quotes'][quotes['quotes'].keys.sample]
end

quote = get_random_quote(get_quotes)
author_string = "-- #{quote['author']}"

# Get author name aligned to the right
cols = `tput cols`
second_string = String.new
(cols.to_i - author_string.length - 2).times {|i| second_string << " "}
second_string << author_string

puts "  #{quote['quote']}"
puts second_string
