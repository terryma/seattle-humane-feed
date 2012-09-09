require 'sinatra'

get '/' do
    "Hello world!"
end

get '/scrape' do
    load 'cat_scraper.rb'
end


