## Thing
# RESTful API example
# - manages single resource called Thing /thing
# - all results (including error messages) returned as JSON (Accept header)

## requires
require 'sinatra'
require 'rubygems'
require 'sinatra/base'
require 'json'
require 'time'
require 'pp'

### datamapper requires
require 'data_mapper'
require 'dm-types'
require 'dm-timestamps'
require 'dm-validations'

## model
### helper modules
#### StandardProperties
module StandardProperties
  def self.included(other)
    other.class_eval do
      property :id, other::Serial
      property :created_at, DateTime
      property :updated_at, DateTime
    end
  end
end

#### Validations
module Validations
  def valid_id?(id)
    id && id.to_s =~ /^\d+$/
  end
end
class DnsZone
	include DataMapper::Resource
	include StandardProperties
        extend Validations
	# property <name>, <type>
	property :id, Serial
	property :name, String, :required => true, :length => 255
	property :mail, String, :required => true, :default => 'hostmaster@levelip.com', :length => 255
	property :ttl, Integer, :required => true, :default => 86400
	property :serial, Integer, :required => true, :default => lambda { DateTime.now.strftime("%Y%m%d00").to_i }
	property :refresh, Integer, :required => true, :default => 10800
	property :retry, Integer, :required => true, :default => 3600
	property :expire, Integer, :required => true, :default => 604800
	property :minimum, Integer, :required => true, :default => 3600
	property :active, Boolean, :required => true, :default => true

	#belongs_to :customer
	has n, :dns_records

	def generate_serial
		today = Time.now.strftime('%Y%m%d')
		self.serial = (self.serial.to_s[0..7] == today ? self.serial += 1 : today + '00')
	end

end

class DnsRecord
   	include DataMapper::Resource
        include StandardProperties
        extend Validations
	property :id, Serial
	property :name, String, :required => false, :length => 255, :index => [:name, :name_active_zone, :name_active_rtype_zone]
	property :type, String, :required => true, :default => 'a', :length => 10, :index => [:name_active_rtype_zone]
	#property :content, String, :required => true, :length => 255
	property :content, IPAddress, :required => true, :length => 255
	property :prio, Integer, :default => 10
	property :ttl, Integer, :default => 86400
	property :active, Boolean, :required => true, :default => true, :index => [:name_active_zone, :name_active_rtype_zone]

	#belongs_to :customer, :required => false

	belongs_to :dns_zone, :key => true #, :index => [:name_active_zone, :name_active_rtype_zone]

	before :valid?, :cleanup
	before :save, :cleanup

	def cleanup
		self.prio = nil if self.prio == ""
		self.ttl = nil if self.ttl == ""
	end

end

## set up db
env = ENV["RACK_ENV"]
puts "RACK_ENV: #{env}"
if env.to_s.strip == ""
  abort "Must define RACK_ENV (used for db name)"
end

case env
when "test"
  DataMapper.setup(:default, "sqlite3::memory:")
else
  DataMapper.setup(:default, "sqlite3:#{ENV["RACK_ENV"]}.db")
end

## create schema if necessary
DataMapper.auto_upgrade!

## logger
def logger
  @logger ||= Logger.new(STDOUT)
end

## diennesse application
#module DieNneSse
class DieNneSse < Sinatra::Base
  set :methodoverride, true
## lista tutte le zone
get "/test" do
	data = 'bla'
	JSONP = data
end
get "/zone/all", :provides => :json do
    content_type :json

    if zone = DnsZone.all
      zone.to_json
    else
      json_status 404, "Not found"
    end
  end
## tutti i record
get "/records/all", :provides => :json do
    content_type :json

    if records = DnsRecord.all
      records.to_json
    else
      json_status 404, "Not found"
    end
  end

## lista zona dato il nome
  get "/zona/:name" do #, :provides => :json do
    content_type :json
      if zona = DnsZone.first(:name => params[:name])
        records = zona.dns_records.all
        records.to_json
      else
        #json_status 404, "Not found"
      end
  end

get "/zona/:id/records", :provides => :json do
    content_type :json
    # check that :id param is an integer
    if DnsZone.valid_id?(params[:id])
      if zona = DnsZone.first(:id => params[:id].to_i)
        records = zona.dns_records.all(:dns_zone_id => params[:id].to_i)
        records.to_json 
      else
        json_status 404, "Not found"
      end
    else
      # TODO: find better error for this (id not an integer)
      json_status 404, "Not found"
    end
  end

## id della zona dato il nome
  get "/zona_id/:name", :provides => :json do
    content_type :json
      if zone_id = DnsZone.first(:name => params[:name])[:id]
        #{ :id => zone_id }.to_json
      zone_id.to_json
      else
        json_status 404, "Not found"
      end
  end
 
 

 post "/record/new", :provides => :json do
        content_type :json
        new_params = accept_params(params, :name, :type, :content, :prio, :ttl)
                if zona = DnsZone.first(:name => params[:zona].to_s)
                        newrecord = zona.dns_records.create(new_params)
                if zona.dns_records.save
                        zona.dns_records.to_json
                        else
                        json_status 400, zona.dns_records.errors.to_hash
                end
                else
                        json_status 404, "Not found"
                end
  end

 put "/record/edit", :provides => :json do
        content_type :json
        new_params = accept_params(params, :id, :name, :type, :content, :prio, :ttl)
                if zona = DnsZone.first(:name => params[:zona].to_s)
                        modified = zona.dns_records.first(:id => params[:id].to_s)
                        modified.attributes = modified.attributes.merge(new_params)
                if modified.save
                        zona.dns_records.to_json
                        else
                        json_status 400, zona.dns_records.errors.to_hash
                end
                else
                        json_status 404, "Not found"
                end
  end


 post "/record/:zona/add", :provides => :json do
        content_type :json
        new_params = accept_params(params, :name, :type, :content, :prio, :ttl)
                if zona = DnsZone.first(:name => params[:zona].to_s)
                        newrecord = zona.dns_records.create(new_params)
                if zona.dns_records.save
                        zona.dns_records.to_json
                        else
                        json_status 400, zona.dns_records.errors.to_hash
                end
                else
                        json_status 404, "Not found"
                end
  end

post "/zona/new/:name", :provides => :json do
    content_type :json
    new_params = accept_params(params, :name)
    zona = DnsZone.new(new_params)
    if zona.save
      headers["Location"] = "/zona/#{zona.id}"
      # http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.5
      status 201 # Created
      #zona.to_json
    else
      json_status 400, zona.errors.to_hash
    end
  end

delete "/zona/delete/:id", :provides => :json do
	content_type :json
	if zona = DnsZone.first(:id => params[:id].to_i)
		zona.destroy!
		status 204
	else
		json.status 404, "Not Found"
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
  
  ## misc handlers: error, not_found, etc.
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
#end
