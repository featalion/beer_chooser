require 'faraday'
require 'json'
require 'lru_redux'

module BeerChooser
  class APIClient
    DEFAULT_ENDPOINT = 'https://api.punkapi.com/v2'.freeze
    CACHE_SIZE = 20.freeze
    CACHE_TTL = 120.freeze # seconds
    REQUEST_TIMEOUT = 5.freeze # seconds

    def initialize(endpoint: DEFAULT_ENDPOINT,
                   cache_size: CACHE_SIZE,
                   cache_ttl: CACHE_TTL,
                   connection: nil)
      # if a connection is provided, endpoint option will be ignored
      @connection = connection
      @endpoint = endpoint
      @cache = LruRedux::TTL::Cache.new(cache_size, cache_ttl)
    end

    def beers_by_name(name)
      prepared_name = normalize_beer_name(name)
      with_cache(prepared_name) do
        resp = connection.get('beers') do |req|
          req.params['beer_name'] = prepared_name
        end
        JSON.parse(resp.body).map do |beer_map|
          Beer.new(beer_map)
        end
      end
    end

    private

    def normalize_beer_name(name)
      name.strip.gsub(/\s+/, '_').downcase
    end

    def connection
      @connection ||= Faraday.new(
        url: @endpoint,
        headers: {'Content-Type' => 'application/json'},
        request: {:timeout => REQUEST_TIMEOUT}
      )
    end

    def with_cache(key)
      @cache[key] ||= yield
    end
  end
end
