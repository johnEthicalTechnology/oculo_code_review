require "rack/test"
require "securerandom"
require 'securerandom'
require 'nokogiri'

RSpec.configure do |config|
  config.include Rack::Test::Methods
end

def create_tables(db)
  db.execute(<<-SQL
      create table messages (
             id varchar(255),
             to_user varchar(255),
             from_user varchar(255),
             message varchar(255),
             status varchar(255));
             SQL
            )
  db.execute(<<-SQL
      create table users(
             id varchar(255));
             SQL
            )
end

def seed_for_create_message(db, to_id, from_id)
  db.execute(<<-SQL
      insert into users(id)
      values
        ("#{to_id}"),
        ("#{from_id}");
        SQL
            )
end

def seed_for_get_status(db, id, status)
  db.execute(<<-SQL
      insert into messages(id, to_user, from_user, message, status)
      values('#{id}', '#{SecureRandom.uuid}', '#{SecureRandom.uuid}', 'this is a test', '#{status}');
        SQL
            )
end

def clear_db(db)
  db.execute(<<-SQL
      drop table users;
      SQL
            )
  db.execute(<<-SQL
      drop table messages;
      SQL
            )
end

RSpec::Matchers.define :have_message_record do |id|
  match do |db|
    @id = id
    row = db.execute(<<-SQL
        SELECT #{@attr}, from_user FROM messages WHERE id ='#{id}'
        SQL
    )
    row.any? && row.flatten.first == @value
  end

  match_when_negated do |db|
    db.execute(<<-SQL
        SELECT * FROM messages
        SQL
              ).none?
  end

  description do
    if @id.present?
      "have message record id: #{@id} with #{@attr} = #{@value}"
    else
      "have message record"
    end
  end


  chain :with_attributes do |attr, value|
    @attr = attr
    @value = value
  end
end
