# dev hint: shotgun login.rb

require 'rubygems'
require 'sinatra'
require 'rest-client'
require 'json'
require 'rack-flash'

class Admin < Sinatra::Base

use Rack::Flash
enable :sessions

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
  @title = 'DNS - New'
  erb :addrecord
end

get '/zona/:name/edit' do
  @title = 'DNS - ' + params[:name] + ' Add Record'
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
    flash[:notice] = "Record created"
    redirect '/zona/' + params[:zona] + '/edit'
  end
end

post '/record/edit/?' do
  new_params = accept_params(params, :id, :zona, :name, :type, :content, :prio, :ttl)
  #@call = "http://localhost:8080/record" + "/" + "#{params[:id]}" + "/edit/"
  #response = RestClient.put @call,
  response = RestClient.put 'http://localhost:8080/record/edit',
        {
                :id => params[:id],
                :zona => params[:zona],
                :name => params[:name],
                :type => params[:type],
                :content => params[:content],
                :prio => params[:prio],
                :ttl => params[:ttl]
        }
  case response.code
  when 200
    flash[:notice] = "record updated"
    redirect '/zona/' + params[:zona] + '/edit'
  end
end

get '/zona/delete/:id' do 
 new_params = accept_params(params, :id, :zona, :name)
 @call = "http://localhost:8080/zona/delete" + "/" + "#{params[:id]}"
 response = RestClient.delete @call
 case response.code
  when 204
    flash[:notice] = "zone deleted"
    redirect '/domini'
  end

end

get '/record/:zona/delete/:id' do
  #new_params = accept_params(params, :id, :zona, :name)
  @call = "http://localhost:8080/record" + "/" + "#{params[:zona]}" + "/" + "delete" + "/" + "#{params[:id]}"
  #response = RestClient.put @call,
  response = RestClient.delete @call
  case response.code
  when 204
    flash[:notice] = "record deleted"
    redirect '/zona/' + params[:zona] + '/edit'
  end
end

post '/zona/new/?' do 
  @title = 'DNS - New'
  @call = "http://localhost:8080/zona/new" + "/" + "#{params[:name]}"
  response = RestClient.post @call, :content_type => :json
  case response.code
  when 201
    flash[:notice] = "Zone created"
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

