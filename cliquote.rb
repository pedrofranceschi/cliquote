#!/usr/bin/env ruby
# frozen_string_literal: true

# cliquote - displays a random quote in your command line.
#
# Sources (tried in order, first one that answers wins):
#   1. DummyJSON  - https://dummyjson.com/quotes/random
#   2. ZenQuotes  - https://zenquotes.io/api/random  (free tier: 5 requests / 30 s)
#   3. A small built-in list, used when there is no network.
#
# Only Ruby's standard library is used; no gems to install.

require 'net/http'
require 'json'
require 'io/console'
require 'optparse'

module Cliquote
  Quote = Struct.new(:text, :author)

  class FetchError < StandardError; end

  TIMEOUT = 5 # seconds, for both connecting and reading

  SOURCES = {
    'dummyjson' => {
      url: 'https://dummyjson.com/quotes/random',
      parse: lambda { |data|
        Quote.new(data['quote'], data['author'])
      }
    },
    'zenquotes' => {
      url: 'https://zenquotes.io/api/random',
      parse: lambda { |data|
        item = Array(data).first || {}
        # When rate limited, ZenQuotes answers with a "quote" signed by itself.
        raise FetchError, 'rate limited' if item['a'].to_s.include?('zenquotes.io')

        Quote.new(item['q'], item['a'])
      }
    }
  }.freeze

  OFFLINE_QUOTES = [
    Quote.new('The unexamined life is not worth living.', 'Socrates'),
    Quote.new('We are what we repeatedly do. Excellence, then, is not an act, but a habit.', 'Will Durant'),
    Quote.new('Simplicity is prerequisite for reliability.', 'Edsger W. Dijkstra'),
    Quote.new('Talk is cheap. Show me the code.', 'Linus Torvalds'),
    Quote.new('It always seems impossible until it is done.', 'Nelson Mandela'),
    Quote.new('Imagination is more important than knowledge.', 'Albert Einstein'),
    Quote.new('Programs must be written for people to read, and only incidentally for machines to execute.',
              'Harold Abelson'),
    Quote.new('The best way to predict the future is to invent it.', 'Alan Kay')
  ].freeze

  module_function

  def fetch_json(url, redirects_left: 3)
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port,
                               use_ssl: uri.scheme == 'https',
                               open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.get(uri.request_uri, 'Accept' => 'application/json', 'User-Agent' => 'cliquote')
    end

    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)
    when Net::HTTPRedirection
      raise FetchError, 'too many redirects' if redirects_left.zero?

      fetch_json(URI.join(url, response['location']).to_s, redirects_left: redirects_left - 1)
    else
      raise FetchError, "HTTP #{response.code}"
    end
  rescue JSON::ParserError
    raise FetchError, 'invalid JSON in response'
  rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
    raise FetchError, e.message
  end

  def fetch_quote(source_name)
    source = SOURCES.fetch(source_name)
    quote = source[:parse].call(fetch_json(source[:url]))
    raise FetchError, 'empty quote' if quote.text.to_s.strip.empty?

    quote.author = 'Unknown' if quote.author.to_s.strip.empty?
    quote
  end

  # Tries each source in order. Returns [quote, errors].
  def random_quote(sources, offline_fallback: true)
    errors = []
    sources.each do |name|
      return [fetch_quote(name), errors]
    rescue FetchError => e
      errors << "#{name}: #{e.message}"
    end
    raise FetchError, errors.join('; ') unless offline_fallback

    [OFFLINE_QUOTES.sample, errors]
  end

  def terminal_width
    width = IO.console&.winsize&.last.to_i
    width = ENV['COLUMNS'].to_i if width.zero?
    width.positive? ? width : 80
  end

  # Greedy word wrap; words longer than the width are split.
  def wrap(text, width)
    width = [width, 10].max
    lines = []
    line = +''
    text.split.each do |word|
      while word.length > width
        lines << line unless line.empty?
        lines << word[0, width]
        word = word[width..]
        line = +''
      end
      if line.empty?
        line = word.dup
      elsif line.length + 1 + word.length <= width
        line << ' ' << word
      else
        lines << line
        line = word.dup
      end
    end
    lines << line unless line.empty?
    lines
  end

  def format(quote, width)
    margin = 2
    body = wrap(quote.text.strip, width - (margin * 2)).map { |l| (' ' * margin) + l }
    author = "-- #{quote.author.strip}"
    author = author.rjust(width - margin) if author.length < width - margin
    ['', *body, '', author, ''].join("\n")
  end

  # True when the program got a console window of its own, which on Windows
  # means it was started by double-clicking the file. That window closes as
  # soon as the program ends, so we wait for Enter before exiting.
  # When run from an open cmd/PowerShell, the console is shared with the
  # shell and this returns false.
  def own_console_window?
    return false unless Gem.win_platform?

    require 'fiddle'
    kernel32 = Fiddle.dlopen('kernel32')
    get_list = Fiddle::Function.new(kernel32['GetConsoleProcessList'],
                                    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG], Fiddle::TYPE_LONG)
    get_list.call("\0" * 64, 16) == 1
  rescue LoadError, StandardError
    false
  end

  def wait_for_enter
    print 'Press Enter to close...'
    $stdin.gets
  rescue StandardError
    nil
  end

  def parse_options(argv)
    options = { sources: SOURCES.keys, width: nil, offline: false, verbose: false, pause: false }
    OptionParser.new do |opts|
      opts.banner = 'Usage: cliquote.rb [options]'
      opts.on('-s', '--source NAME', SOURCES.keys,
              "Use only this source (#{SOURCES.keys.join(', ')})") { |s| options[:sources] = [s] }
      opts.on('-o', '--offline', 'Use the built-in quotes, no network') { options[:offline] = true }
      opts.on('-w', '--width N', Integer, 'Output width (default: terminal width)') { |w| options[:width] = w }
      opts.on('-v', '--verbose', 'Report sources that failed') { options[:verbose] = true }
      opts.on('-p', '--pause', 'Wait for Enter before exiting') { options[:pause] = true }
      opts.on('-h', '--help', 'Show this help') do
        puts opts
        exit
      end
    end.parse!(argv)
    options
  end

  def run(argv)
    pause = own_console_window? || argv.include?('-p') || argv.include?('--pause')
    status = show_quote(argv)
    wait_for_enter if pause
    status
  end

  def show_quote(argv)
    options = parse_options(argv)
    quote, errors =
      if options[:offline]
        [OFFLINE_QUOTES.sample, []]
      else
        random_quote(options[:sources])
      end

    if options[:verbose] && errors.any?
      warn "cliquote: #{errors.join('; ')}"
      warn 'cliquote: showing a built-in quote instead' if OFFLINE_QUOTES.include?(quote)
    end

    puts format(quote, options[:width] || terminal_width)
    0
  rescue OptionParser::ParseError => e
    warn "cliquote: #{e.message} (see --help)"
    2
  rescue StandardError => e
    warn "cliquote: unexpected error: #{e.class}: #{e.message}"
    1
  end
end

exit Cliquote.run(ARGV) if $PROGRAM_NAME == __FILE__
