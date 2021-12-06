require 'beer_chooser'

require_relative 'api_responses'

describe BeerChooser::UserInterface do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:connection) { Faraday.new { |b| b.adapter(:test, stubs) } }
  let(:client) { BeerChooser::APIClient.new(connection: connection) }
  let(:ui) { BeerChooser::UserInterface.new(client) }

  it 'starts in the :initialized state' do
    expect(ui.aasm.current_state).to eq(:initialized)
  end

  it 'should end up in :asking_for_beer_name after launch' do
    allow(CLI::UI).to receive(:ask).and_return(nil)
    allow(ui).to receive(:search_for_beers).and_return(nil)

    expect { ui.run }.to output(/Welcome to BeerChooser!/).to_stdout
    expect(ui.aasm.current_state).to eq(:asking_for_beer_name)
  end

  it 'should find some beers' do
    allow(CLI::UI).to receive(:ask).and_return('IPA')
    allow(CLI::UI::Prompt).to receive(:ask).and_return('Quit')
    stubs.get('/beers') do |env|
      expect(env.url.path).to eq('/beers')
      APIResponses.several_beers(3)
    end

    expect { ui.run }.to output(/Beers that match/).to_stdout_from_any_process
    expect(ui.aasm.current_state).to eq(:showing_beers)
  end

  it 'should ask for beer name again when no beers have been found' do
    asks_count = 0
    allow(CLI::UI).to receive(:ask) { "IPA ##{asks_count}" } # avoids cache
    allow(CLI::UI::Prompt).to receive(:ask).and_return('Quit')
    stubs.get('/beers') do |env|
      expect(env.url.path).to eq('/beers')
      resp = APIResponses.several_beers(asks_count)
      asks_count += 1 # avoids endless recursive calls
      resp
    end

    # No beers on the first request
    expect { ui.run }.to output(/No beers have been found/).to_stdout_from_any_process
    expect(ui.aasm.current_state).to eq(:showing_beers)
  end

  it 'should show a beer' do
    beer = APIResponses.brew
    allow(CLI::UI).to receive(:ask).and_return('IPA')
    first_prompt = true
    allow(CLI::UI::Prompt).to receive(:ask) do
      if first_prompt
        first_prompt = false # avoids endless recursive calls
        beers = ui.instance_variable_get(:@beers)
        ui.instance_variable_set(:@selected_beer, beers[0])
        ui.show_beer
      end
    end
    stubs.get('/beers') do |env|
      expect(env.url.path).to eq('/beers')
      APIResponses.response([beer])
    end

    expect { ui.run }.to output(/Unique IPA #1/).to_stdout_from_any_process
    expect(ui.aasm.current_state).to eq(:showing_beer_details)
  end
end
