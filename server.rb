require "sinatra/base"
require "sqlite3"
require "nokogiri"
require 'active_support/core_ext'
require 'json'

class Server < Sinatra::Base

  # {
  #  to: <USER ID>
  #  from: <USER_ID>
  #  message: <MESSAGE BODY>
  #
  # }

  post '/messages/:format?' do
    case params['format']
    when 'json' then
      message = JSONMessage.new(request.body)
      if message.valid?
        message.save
        message.send_message
        [200]
      else
        [400]
      end
    when 'xml'
      message = XMLMesaage.new(request.body)
      if message.valid?
        message.save
        message.send_message
        [200]
      else
        [400]
      end
    else
      [400, 'format not supported']
    end
  end

  get '/messages/:id/status/:format?' do
    status = db.execute("SELECT status from messages WHERE id = #{params['id']} LIMIT 1")
    return [400, 'not found'] if status.empty?
    case params['format']
    when 'json'
      [200, {message: { status: status[:status] } }.to_json ]
    when 'xml'
      [200, { status: status[:status] }.to_xml(root: 'message')]
    else
      [400, 'format not supported']
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
      return false if db.execute("SELECT * from users where id = #{@to} LIMIT 1").empty?
      return false if db.execute("SELECT * from users where id = #{@from} LIMIT 1").empty?
      true
    end

    def save
      @id = SecureRandom.uuid
      db.execute(<<~SQL
        INSERT INTO messages(id, to, from, message, status)
        VALUES('#{@id}', '#{@to}','#{@from}', '#{@message}, 'pending');
        SQL
      )
    end

    def send_message
      sent = ExternalApiClient.new.send_message({to: @to, from: @from, message: @message})
      if sent
        db.execute(<<-SQL
          UPDATE messages
          SET status = 'sent'
          WHERE id = #{@id};
        SQL
                  )
      else
        db.execute(<<-SQL
          UPDATE messages
          SET status = 'failed'
          WHERE id = #{@id};
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
      to = data.xpath('//to').text
      from = data.xpath('//from').text
      message = data.xpath('//message').text
      [to, from, message]
    end

    def valid?
      return false if [@to, @from, @message].any?(&:nil?)
      return false if db.execute("SELECT * from users where id = #{@to} LIMIT 1").empty?
      return false if db.execute("SELECT * from users where id = #{@from} LIMIT 1").empty?
      true
    end

    def save
      @id = SecureRandom.uuid
      db.execute(<<~SQL
        INSERT INTO messages(id, to, from, message, status)
        VALUES('#{@id}', '#{@to}','#{@from}', '#{@message}, 'pending');
        SQL
      )
    end

    def send_message
      sent = ExternalApiClient.new.send_message({to: @to, from: @from, message: @message})
      if sent
        db.execute(<<-SQL
          UPDATE messages
          SET status = 'sent'
          WHERE id = #{@id};
        SQL
                  )
      else
        db.execute(<<-SQL
          UPDATE messages
          SET status = 'failed'
          WHERE id = #{@id};
        SQL
                  )
      end
    end

    def db
      SQLite3::Database.new "test.db"
    end
  end

  class ExternalApiClient

    def initialize
      # some config here
    end

    def send_message(message_hash)
      sleep 10
      [true, false].sample
    end
  end

end
