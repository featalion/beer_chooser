class APIResponses
  class << self
    def several_beers(num)
      beers = num.times.collect { |i| brew(i + 1) }
      response(beers)
    end

    def brew(id = 1)
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
