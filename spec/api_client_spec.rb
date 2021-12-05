require 'faraday'
require 'json'
require 'beer_chooser'

describe BeerChooser::APIClient do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:connection) { Faraday.new { |b| b.adapter(:test, stubs) } }
  let(:client) { BeerChooser::APIClient.new(connection: connection) }

  it 'finds beers' do
    beers_count = 3
    stubs.get('/beers') do |env|
      expect(env.url.path).to eq('/beers')
      APIResponses.several_beers(beers_count)
    end

    response = client.beers_by_name('IPA')
    expect(response.size).to eq(beers_count)
    expect(response).to all(be_a(BeerChooser::Beer))
  end

  it 'does not find any beers' do
    beers_count = 0
    stubs.get('/beers') do |env|
      expect(env.url.path).to eq('/beers')
      APIResponses.several_beers(beers_count)
    end

    response = client.beers_by_name('IPA')
    expect(response.size).to eq(beers_count)
  end

  it 'should timeout on long running requests' do
    allow(connection).to receive(:get).and_raise(Faraday::TimeoutError)

    expect { client.beers_by_name('IPA') }.to raise_error(Faraday::TimeoutError)
  end
end

class APIResponses
  class << self
    def several_beers(num)
      beers = num.times.collect { |i| generate_beer(i + 1) }
      response(beers)
    end

    def generate_beer(id = 1)
      name = "Unique IPA ##{id}"
      description = "Description of #{name}"
      foods = ['Food 1', 'Food 2']
      {id: id, name: name, description: description, food_pairing: foods}
    end

    def response(body, code: 200)
      [200, {'Content-Type' => 'application/json'}, body.to_json]
    end
  end
end
