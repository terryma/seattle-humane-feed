require 'nokogiri'
require 'open-uri'
require 'sequel'
require 'pony'

# Set mail options
Pony.options = {
          sender: 'Seattle Humane Society',
          via: :smtp,
          via_options: { address: 'smtp.gmail.com',
              port: '587',
              enable_starttls_auto: true,
              user_name: 'seattlehumane.feed',
              password: 'iluvcats',
              authentication: 'plain',
              domain: 'localhost.localdomain'
          },
          subject: 'New cats at Seattle Humane Society!'
}

# Connect to Postgres db
DB = Sequel.connect(ENV['DATABASE_URL'] || "postgres://localhost/terry")

cats = DB[:cats]
link = "http://www.seattlehumane.org"

doc = Nokogiri::HTML(open("http://www.seattlehumane.org/adopt/pets/cats/all"))
# Load local file for testing
#doc = Nokogiri::HTML(File.open(File.dirname(__FILE__) + "/cats.html"))


body = ""

doc.css('div.pet_search_right').each do |c|
    cat = {}
    id = c.css('> a').first
    cat[:id] = id['href'].split('/').last.to_i
    cat[:name] = id.css('strong').first.content
    cat[:link] = link+id['href']
    cat[:first_available] = Time.now.utc
    cat[:last_available] = Time.now.utc

    # See if this cat already exists
    db_cat = cats.where(id:cat[:id])
    if (db_cat)
        # update the last available time
        db_cat.update(last_available: Time.now.utc)
    else
        # add the cat in
        p "Adding new cat with id #{cat[:id]}, name #{cat[:name]}"
        cats.insert(id: cat[:id],
                    name: cat[:name],
                    first_available: cat[:first_available],
                    last_available: cat[:last_available]
                   )
    end
    body << "<p><a href='#{cat[:link]}'>#{cat[:name]}</a></p>"
end

puts "total cats = #{cats.count}"
Pony.mail(to: 'zhenchuan.ma@gmail.com', 
          html_body: body)

