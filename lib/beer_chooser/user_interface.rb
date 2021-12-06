require 'cli/ui'
require 'aasm'

module BeerChooser
  class UserInterface
    include AASM

    PER_PAGE = 10.freeze

    def initialize(client = nil)
      CLI::UI::StdoutRouter.enable
      @client = client || BeerChooser::APIClient.new
    end

    def run
      puts CLI::UI.fmt('{{cyan:Welcome to BeerChooser!}}')
      show_name_prompt
    end

    def quit
      puts CLI::UI.fmt '{{*}} {{green:{{bold:See you next time!}}}} {{*}}'
    end

    aasm do
      state :initialized, initial: true
      state :asking_for_beer_name, after_enter: :name_prompt
      state :searching_beers, after_enter: :search_beers
      state :showing_beers, after_enter: :show_beers_list
      state :showing_beer_details, after_enter: :show_beer_details

      event :show_name_prompt do
        transitions from: [:initialized,
                           :showing_beers,
                           :showing_beer_details,
                           :searching_beers],
                    to: :asking_for_beer_name
      end

      event :search_for_beers do
        transitions from: :asking_for_beer_name, to: :searching_beers
      end

      event :show_beers do
        transitions from: [:searching_beers, :showing_beers, :showing_beer_details],
                    to: :showing_beers
      end

      event :show_beer do
        transitions from: :showing_beers, to: :showing_beer_details
      end
    end

    private

    def name_prompt
      @current_name = CLI::UI.ask('Type a name of a beer or its part (Ctrl-C to exit)',
                                  allow_empty: false)
      search_for_beers
    end

    def search_beers
      reset_pagination
      begin
        @beers = @client.beers_by_name(@current_name)
      rescue Faraday::ConnectionFailed
        handle_error 'Cannot connect to Punk API'
      rescue Faraday::TimeoutError
        handle_error 'Punk API is too slow'
      else
        unless @beers.empty?
          show_beers
        else
          puts CLI::UI.fmt '{{x}} {{error:No beers have been found by your request}}'
          show_name_prompt
        end
      end
    end

    def show_beers_list
      page_info = "({{info:page #{@current_page} of #{total_number_of_pages}}})"
      puts CLI::UI.fmt "{{cyan:Beers that match '#{@current_name}' #{page_info}}}"

      CLI::UI::Prompt.ask('') do |handler|
        beers_on_current_page.each do |beer|
          beer_name = "{{bold:{{green:#{beer.caption}}}}}"
          handler.option(beer_name) do
            @selected_beer = beer
            show_beer
          end
        end

        option_search_another_beer(handler)
        option_next_page(handler)
        option_prev_page(handler)
        option_quit(handler)
      end
    end

    def show_beer_details
      puts CLI::UI.fmt "Name: {{bold:{{green:#{@selected_beer.name}}}}}"
      puts CLI::UI.fmt "Alcohol by Volume: {{bold:{{red:#{@selected_beer.abv}}}}}"
      puts
      puts @selected_beer.description
      puts
      show_matching_food
      puts

      CLI::UI::Prompt.ask('Available actions:') do |handler|
        handler.option('{{yellow:Back to the list}}') { show_beers }
        option_search_another_beer(handler)
        option_quit(handler)
      end
    end

    def show_matching_food
      if @selected_beer.good_to.empty?
        puts CLI::UI.fmt '{{x}} {{red:Matching food list is not provided}}'
      else
        puts 'Good to:'
        @selected_beer.good_to.each do |food|
          puts CLI::UI.fmt "{{v}} #{food}"
        end
      end
    end

    def handle_error(message)
      puts CLI::UI.fmt "{{x}} {{red:#{message}, try again later}}"
      show_name_prompt
    end

    def option_quit(handler)
      handler.option('{{red:Quit}}') { quit }
    end

    def option_search_another_beer(handler)
      handler.option('{{yellow:Search for another beer}}') { show_name_prompt }
    end

    def option_next_page(handler)
      if @beers.size > @current_page * PER_PAGE
        handler.option('{{yellow:Next page}}') { next_page }
      end
    end

    def option_prev_page(handler)
      if @current_page > 1
        handler.option('{{yellow:Previous page}}') { prev_page }
      end
    end

    def beers_on_current_page
      @beers.slice((@current_page - 1) * PER_PAGE, PER_PAGE)
    end

    def reset_pagination
      @current_page = 1
    end

    def next_page
      @current_page += 1
      show_beers
    end

    def prev_page
      @current_page -= 1
      show_beers
    end

    def total_number_of_pages
      @beers.size / PER_PAGE + 1
    end
  end
end
