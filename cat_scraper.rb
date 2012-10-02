require 'nokogiri'
require 'open-uri'
require 'sequel'
require 'pony'
require 'erb'
require 'ostruct'

def render_email(cats)
    ERB.new(IO.read(File.dirname(__FILE__) + "/email_template.erb")).result(OpenStruct.new({cats: cats}).instance_eval { binding })
end

ENVIRONMENT = ENV['ENVIRONMENT']
CONFIG = YAML.load_file("./config.yml")[ENVIRONMENT]
puts "Loaded config: #{CONFIG}"

# Set mail options
Pony.options = {
          sender: 'Seattle Humane Society',
          via: :smtp,
          via_options: { address: 'smtp.gmail.com',
              port: '587',
              enable_starttls_auto: true,
              user_name: 'seattlehumane.feed',
              password: ENV['EMAIL_PASSWORD'],
              authentication: 'plain',
              domain: 'localhost.localdomain'
          },
          subject: 'New cats at Seattle Humane Society!'
}

# Connect to Postgres db
DB = Sequel.connect(ENV['DATABASE_URL'])

cats = DB[:cats]
link = "http://www.seattlehumane.org"

if (ENVIRONMENT == 'development')
    doc = Nokogiri::HTML(File.open(File.dirname(__FILE__) + "/cats.html"))
else
    doc = Nokogiri::HTML(open("http://www.seattlehumane.org/adopt/pets/cats/all"))
end

body = ""
new_cats = []

doc.css('div.pet_search_right').each do |c|
    cat = {}
    id = c.css('> a').first
    cat[:id] = id['href'].split('/').last.to_i
    cat[:name] = id.css('strong').first.content
    cat[:link] = link+id['href']
    cat[:first_available] = Time.now.utc
    cat[:last_available] = Time.now.utc
   
    # Parse the text in the poorly written html
    text = c.text
    lines = text.lines
    lines = lines.map do |line|
        next if line.strip == ""
        line.strip
    end.compact!

    # hacky
    if lines.size == 6
        lines = lines.drop(2)
    elsif lines.size == 5
        lines = lines.drop(1)
    end

    cat[:breed] = lines[0]
    cat[:sex] = lines[1].split('|').first.strip
    cat[:size] = lines[1].split('|').last.strip
    cat[:age] = lines[2]
    cat[:status] = lines[3].gsub(/Adoption Status: /, '')
    cat[:photo] = c.css('div.pet_photo img').first['src']
    #puts "cat: #{cat}"

    # See if this cat already exists
    puts "checking cat with id #{cat[:id]}"
    db_cat = cats.where(id:cat[:id])
    if not db_cat.empty?
        # update the last available time
        db_cat.update(last_available: Time.now.utc)
    else
        # add the cat in
        p "Adding new cat with id #{cat[:id]}, name #{cat[:name]}"
        cats.insert(id: cat[:id],
                    name: cat[:name],
                    first_available: cat[:first_available],
                    last_available: cat[:last_available],
                    breed: cat[:breed],
                    sex: cat[:sex],
                    size: cat[:size],
                    age: cat[:age],
                    status: cat[:status],
                    photo: cat[:photo]
                   )
        new_cats << cat
    end
    body = render_email(new_cats)
end

puts "total cats = #{cats.count}"
if (new_cats.empty?)
    puts "No new cats, not sending email"
else
    puts "Sending email to #{CONFIG['email']}"
    Pony.mail(to: CONFIG['email'], html_body: body)
end


