require 'rubygems'
require 'neography'
require 'sinatra/base'
require 'uri'

class Neovigator < Sinatra::Application
  set :haml, :format => :html5 
  set :app_file, __FILE__

  configure :test do
    require 'net-http-spy'
    Net::HTTP.http_logger_options = {:verbose => true} 
  end

  helpers do
    def link_to(url, text=url, opts={})
      attributes = ""
      opts.each { |key,value| attributes << key.to_s << "=\"" << value << "\" "}
      "<a href=\"#{url}\" #{attributes}>#{text}</a>"
    end

    def neo
      @neo = Neography::Rest.new(ENV["GRAPHENEDB_URL"] || "http://localhost:7474")
    end
  end
  
  def hashify(results)
    results["data"].map {|row| Hash[*results["columns"].zip(row).flatten] }
  end

  def create_graph
    return if neo.execute_query("MATCH (n:Employee) RETURN COUNT(n)")["data"].first.first > 1
  end

helpers do
    def link_to(url, text=url, opts={})
      attributes = ""
      opts.each { |key,value| attributes << key.to_s << "=\"" << value << "\" "}
      "<a href=\"#{url}\" #{attributes}>#{text}</a>"
    end
  end

  def node_id(node)
    case node
      when Hash
        node["self"].split('/').last
      when String
        node.split('/').last
      else
        node
    end
  end

  def get_properties(node)
    properties = "<ul>"
    node.each_pair do |key, value|
      if key == "avatar_url"
        properties << "<li><img src='#{value}'></li>"
      else
        properties << "<li><b>#{key}:</b> #{value}</li>"
      end
    end
    properties + "</ul>"
  end

  get '/resources/show' do
    content_type :json
    id = params[:id]
    if id.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true
    	cypher = "START me=node(#{id}) 
              OPTIONAL MATCH me -[r]- related
              RETURN me, r, related"
    else
	begin
    		name  = URI.decode(params[:id])
		name['+'] = ' '
	rescue => e
	end
	cypher = "MATCH (n {name: '#{name}'}) -[r]- related RETURN n, r, related"
    end
    connections = neo.execute_query(cypher)["data"]   
 
    me = connections[0][0]["data"]
    
    relationships = []
    if connections[0][1]
      connections.group_by{|group| group[1]["type"]}.each do |key,values| 
        relationships <<  {:id => key, 
                     :name => key,
                     :values => values.collect{|n| n[2]["data"].merge({:id => node_id(n[2]) }) } }
      end
    end

    relationships = [{"name" => "No Relationships","values" => [{"id" => "#{params[:id]}","name" => "No Relationships "}]}] if relationships.empty?

    @node = {:details_html => "<h2>#{me["name"]}</h2>\n<p class='summary'>\n#{get_properties(me)}</p>\n",
                :data => {:attributes => relationships, 
                          :name => me["name"],
                          :id => params[:id]}
              }

    @node.to_json


  end

  get '/' do
    #create_graph
    @neoid = params["neoid"] || 1
    haml :index
  end

end
