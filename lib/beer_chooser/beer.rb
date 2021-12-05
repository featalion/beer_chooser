module BeerChooser
  class Beer
    attr_reader :abv
    attr_reader :description
    attr_reader :good_to
    attr_reader :name

    def initialize(beer_map)
      @abv = "#{beer_map['abv']}%"
      @description = beer_map['description']
      @good_to = beer_map['food_pairing'] || []
      @name = beer_map['name']
    end

    def caption
      "#{name} (#{abv})"
    end
  end
end
