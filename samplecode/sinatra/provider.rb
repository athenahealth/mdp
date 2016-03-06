require './model.rb'
require './apirequest.rb'

class Provider < Model
  attr_reader :firstname, :lastname, :specialty, :providertypeid, :providerid

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
    @providertypeid = args['providertypeid']
    @providerid = args['providerid']
  end

  def name
    "#{@firstname} #{@lastname}"
  end
end