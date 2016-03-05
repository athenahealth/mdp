require './model.rb'
require './apirequest.rb'

class Provider < Model
  attr_reader :firstname, :lastname, :specialty

  def self.name
    'providers'
  end

  def self.find args={}
    ApiRequest.new(self, args).try_request
  end

  def initialize args
    @firstname = args['firstname']
    @lastname = args['lastname']
    @specialty = args['specialty']
  end

  def name
    "#{@firstname} #{@lastname}"
  end

  def to_s
    "id: #{@id}\nstate:#{@state}"
  end
end