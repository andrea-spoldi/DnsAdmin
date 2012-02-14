# dev hint: shotgun login.rb

require 'rubygems'
require 'sinatra'
require 'rest-client'
require 'json'


class Admin < Sinatra::Base


configure do
  set :public_folder, Proc.new { File.join(root, "static") }
  enable :sessions
end

get '/' do
  #response = RestClient.get 'http://localhost:8080/zone/all', :content_type => :json
  #zone = JSON.parse(response)
  #@content = zone[0]['name']
  @title = 'DNS'
  #@welcome = "DNS Admin Panel"
  erb :new
end

get '/domini' do
  @title = 'DNS - Zone'
  response = RestClient.get 'http://localhost:8080/zone/all', :content_type => :json
  @zone = JSON.parse(response)
  erb :domini
end

get '/records/:zona' do
  @title = 'DNS - Records'
  @call = "http://localhost:8080/zona" + "/" + params[:zona]
  response = RestClient.get @call, :content_type => :json
  @record = JSON.parse(response)
  erb :records
end

get '/new' do
  @title = 'DNS - Nuova Zona'
  erb :addrecord
end

get '/zona/:name/edit' do
  @title = 'DNS - Add Record'
  @call = "http://localhost:8080/zona" + "/" + params[:name]
  response = RestClient.get @call, :content_type => :json
  @record = JSON.parse(response)
  @zona = params[:name]
  erb :addrecord
end

 post '/record/add/?' do
  new_params = accept_params(params, :zona, :name, :type, :content, :prio, :ttl)
  response = RestClient.post 'http://localhost:8080/record/new', 
	{
		:zona => params[:zona],
                :name => params[:name],
		:type => params[:type],
		:content => params[:content],
		:prio => params[:prio],
		:ttl => params[:ttl]
	}
  case response.code
  when 200
    redirect '/zona/' + params[:zona] + '/edit'
  end
end


post '/zona/new/?' do 
  @title = 'DNS - Nuova Zona'
  @call = "http://localhost:8080/zona/new" + "/" + "#{params[:name]}"
  response = RestClient.post @call, :content_type => :json
  case response.code
  when 201
    redirect '/'
  end
end

 ## helpers

  def self.put_or_post(*a, &b)
    put *a, &b
    post *a, &b
  end

  helpers do
    def json_status(code, reason)
      status code
      {
        :status => code,
        :reason => reason
      }.to_json
    end

    def accept_params(params, *fields)
      h = { }
      fields.each do |name|
        h[name] = params[name] if params[name]
      end
      h
    end
  end

  get "*" do
    status 404
  end

  put_or_post "*" do
    status 404
  end

  delete "*" do
    status 404
  end

  not_found do
    json_status 404, "Not found"
  end

  error do
    json_status 500, env['sinatra.error'].message
  end

end

