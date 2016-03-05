require 'cgi'
require 'json'
require './apiconnection.rb'

class ApiRequest
  def initialize klass, params
    @name = klass.name
    @query = params.map { |k,v| [k,v].map { |x| CGI.escape(x.to_s) }.join('=') }.join('&')

    if @query
      @query = '?' + @query
    end

    @request = Net::HTTP::Get.new("#{klass.base_path}#{@query}")
    @modelclass = klass
  end

  def try_request
    connection = ApiConnection.new

    $authenticator.set_token @request

    response = connection.request(@request)

    if not_authorized response
      puts "Token invalid, attempting to get new token"

      $authenticator.request_token connection
      $authenticator.set_token @request

      response = connection.request(@request)
    end

    models = []

    if not_authorized response
      $global_errors = response
      return []
    end

    if response
      parsed_response = JSON.parse(response.body)
      model_json = parsed_response[@name]
      
      model_json.each do |model_args|
        models << @modelclass.new(model_args)
      end
    end

    models
  end

  def not_authorized response
    response.class == Net::HTTPUnauthorized
    # /^<h1>Not Authorized<\/h1>$/ =~ response
  end

end