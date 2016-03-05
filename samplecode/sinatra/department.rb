require './model.rb'
require './apirequest.rb'

class Department < Model
  attr_reader :name, :state, :zip, :phone

  def self.name
    'departments'
  end

  def self.find args={}
    ApiRequest.new(self, args).try_request
  end

  def initialize args
    @name = args['name']
    @state = args['state']
    @zip = args['zip']
    @phone = args['phone']
  end

  def to_s
    "id: #{@id}\nstate:#{@state}"
  end
end