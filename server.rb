require "sinatra/base"
require "sqlite3"
require "nokogiri"
require 'active_support'
require 'json'
require 'securerandom'

class Server < Sinatra::Base

  # {
  #  to: <UUID>
  #  from: <UUID>
  #  message: <String>
  # }

  post '/messages/:format?' do
    case params['format']
    when 'json' then
      message = JSONMessage.new(request.body.read)
      if message.valid?
        id = message.save

        message.send_message
        [200, {message: {id: id}}.to_json]
      else
        [400]
      end
    when 'xml'
      message = XMLMessage.new(request.body.read)
      if message.valid?
        id = message.save
        message.send_message
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.root do
            xml.message do
              xml.id id
            end
          end
        end
        [200, builder.to_xml]
      else
        [400]
      end
    else
      [400]
    end
  end

  get '/messages/:id/status/:format?' do
    status = db.execute("SELECT status from messages WHERE id = '#{params['id']}' LIMIT 1")
    return [400] if status.empty?
    case params['format']
    when 'json'
      [200, {message: { status: status.flatten.first } }.to_json ]
    when 'xml'
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.root do
          xml.message do
            xml.status status.flatten.first
          end
        end
      end
      [200, builder.to_xml]
    else
      [400]
    end
  end

  def db
    SQLite3::Database.new "test.db"
  end

  class JSONMessage

    def initialize(data)
      @to, @from, @message = parse(data)
    end

    def parse(data)
      parsed_json = JSON.parse(data)
      [parsed_json['to'], parsed_json['from'], parsed_json['message']]
    end

    def valid?
      return false if [@to, @from, @message].any?(&:nil?)
      return false if db.execute("SELECT * from users where id = '#{@to}' LIMIT 1").empty?
      return false if db.execute("SELECT * from users where id = '#{@from}' LIMIT 1").empty?
      true
    end

    def save
      @id = SecureRandom.uuid
      db.execute(<<~SQL
        INSERT INTO messages(id, to_user, from_user, message, status)
        VALUES('#{@id}', '#{@to}','#{@from}', '#{@message}', 'pending');
        SQL
      )
      @id
    end

    def send_message
      sent = ExternalApiClient.send_message({to: @to, from: @from, message: @message})
      if sent
        db.execute(<<-SQL
          UPDATE messages
          SET status = 'sent'
          WHERE id = '#{@id}';
        SQL
                  )
      else
        db.execute(<<-SQL
          UPDATE messages
          SET status = 'failed'
          WHERE id = '#{@id}';
        SQL
                  )
      end
    end

    def db
      SQLite3::Database.new "test.db"
    end
  end

  class XMLMessage

    def initialize(data)
      @to, @from, @message = parse(data)
    end

    def parse(data)
      parsed_xml = Nokogiri::XML(data)
      to = parsed_xml.xpath('//to').text
      from = parsed_xml.xpath('//from').text
      message = parsed_xml.xpath('//message').text
      [to, from, message]
    end

    def valid?
      return false if [@to, @from, @message].any?(&:nil?)
      return false if db.execute("SELECT * from users where id = '#{@to}' LIMIT 1").empty?
      return false if db.execute("SELECT * from users where id = '#{@from}' LIMIT 1").empty?
      true
    end

    def save
      @id = SecureRandom.uuid
      db.execute(<<~SQL
        INSERT INTO messages(id, to_user, from_user, message, status)
        VALUES('#{@id}', '#{@to}','#{@from}', '#{@message}', 'pending');
        SQL
      )
      @id
    end

    def send_message
      sent = ExternalApiClient.send_message({to: @to, from: @from, message: @message})
      if sent
        db.execute(<<-SQL
          UPDATE messages
          SET status = 'sent'
          WHERE id = '#{@id}';
        SQL
                  )
      else
        db.execute(<<-SQL
          UPDATE messages
          SET status = 'failed'
          WHERE id = '#{@id}';
        SQL
                  )
      end
    end

    def db
      SQLite3::Database.new "test.db"
    end
  end

  class ExternalApiClient


    def self.send_message(message_hash)
      sleep 10
      [true, false].sample
    end
  end

end
