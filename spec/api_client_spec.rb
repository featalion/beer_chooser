require 'faraday'
require 'json'
require 'beer_chooser'

require_relative 'api_responses'

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

  it 'should use cached results' do
    beers_count = 2
    stubs.get('/beers') do |env|
      expect(env.url.path).to eq('/beers')
      APIResponses.several_beers(beers_count)
    end

    response = client.beers_by_name('IPA')
    expect(response.size).to eq(beers_count)
    expect(response).to all(be_a(BeerChooser::Beer))

    old_beers_count = beers_count
    beers_count = 0

    response = client.beers_by_name('IPA')
    expect(response.size).to eq(old_beers_count)
    expect(response).to all(be_a(BeerChooser::Beer))
  end

  it 'should timeout on long running requests' do
    allow(connection).to receive(:get).and_raise(Faraday::TimeoutError)

    expect { client.beers_by_name('IPA') }.to raise_error(Faraday::TimeoutError)
  end
end
