require_relative 'server'
require_relative 'spec_helper'

describe Server do
  let(:app) { described_class.new }
  before :all do
    @db = SQLite3::Database.new('test.db')
  end

  after :all do
    File.delete('test.db')
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

  def message_record_with?(db:, id:, attribute:, value:)
    row = db.execute(<<-SQL
        SELECT #{attribute}, from_user FROM messages WHERE id ='#{id}'
        SQL
    )
    row.any? && row.flatten.first == value
  end

  def no_message_record?(db)
    db.execute(<<-SQL
        SELECT * FROM messages
        SQL
              ).none?
  end

  describe 'POST messages' do
    let(:to_id) { SecureRandom.uuid }
    let(:from_id) { SecureRandom.uuid }
    let(:attributes) do
      {
        to: to_id,
        from: from_id,
        message: 'this is a test'
      }
    end
    before do
      create_tables(@db)
      seed_for_create_message(@db, to_id, from_id)
      allow(described_class::ExternalApiClient).to receive(:send_message).and_return(true)
    end

    after do
      clear_db(@db)
    end


    subject(:response) { post "/messages/#{format}", request_body }

    context 'json' do
      let(:format) { 'json' }
      let(:request_body) { attributes.to_json }
      subject(:id) { JSON.parse(response.body)['message']['id'] }

      context 'valid params' do
        specify { expect(response.status).to eq(200) }
        specify 'creates a message db record' do
          expect(message_record_with?(db: @db, id: id, attribute: :to_user, value: attributes[:to])).to be true
          expect(message_record_with?(db: @db, id: id, attribute: :from_user, value: attributes[:from])).to be true
          expect(message_record_with?(db: @db, id: id, attribute: :message, value: attributes[:message])).to be true
        end
        specify 'enqueues the message to be sent' do
          response
          expect(described_class::ExternalApiClient).to have_received(:send_message).with(attributes)
        end
      end

      context 'invalid params' do
        let(:attributes) do
          {
            to: to_id,
            from: 'non-existant-id',
            message: 'this is a test'
          }
        end
        specify "doesn't create a message db record" do
          expect(no_message_record?(@db)).to be true
        end
        specify { expect(response.status).to eq(400) }
      end
    end

    context 'xml' do
      let(:format) { 'xml' }
      let(:request_body) do
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.root do
            xml.to attributes[:to]
            xml.from attributes[:from]
            xml.message attributes[:message]
          end
        end
        builder.to_xml
      end

      subject(:id) { Nokogiri.XML(response.body).xpath("//message/id").text }

      context 'valid params' do
        specify { expect(response.status).to eq(200) }
        specify 'creates a message db record' do
          expect(message_record_with?(db: @db, id: id, attribute: :to_user, value: attributes[:to])).to be true
          expect(message_record_with?(db: @db, id: id, attribute: :from_user, value: attributes[:from])).to be true
          expect(message_record_with?(db: @db, id: id, attribute: :message, value: attributes[:message])).to be true
        end
        specify 'enqueues the message to be sent' do
          response
          expect(described_class::ExternalApiClient).to have_received(:send_message).with(attributes)
        end
      end

      context 'invalid params' do
        let(:attributes) do
          {
            to: to_id,
            from: 'non-existant-id',
            message: 'this is a test'
          }
        end
        specify "doesn't create a message db record" do
          expect(no_message_record?(@db)).to be true
        end
        specify { expect(response.status).to eq(400) }
      end
    end

    context 'other' do
      let(:format) { 'csv' }
      let(:request_body) { '' }
      specify { expect(response.status).to eq(400) }
    end
  end

  describe 'GET /messages/:id/status' do
    let(:id) { SecureRandom.uuid }
    let(:status) { 'sent' }
    before do
      create_tables(@db)
      seed_for_get_status(@db, id, status)
      allow(described_class::ExternalApiClient).to receive(:send_message).and_return(true)
    end

    after do
      clear_db(@db)
    end


    subject(:response) { get "/messages/#{id}/status/#{format}" }

    context 'json' do
      let(:format) { 'json' }
      subject(:returned_status) { JSON.parse(response.body)['message']['status'] }

      context 'message exists' do
        specify { expect(response.status).to eq(200) }
        specify { expect(returned_status).to eq(status) }
      end

      context "message doesn't exist" do
        subject(:response) { get "/messages/notandid/status/#{format}" }
        specify { expect(response.status).to eq(400) }
      end
    end

    context 'xml' do
      let(:format) { 'xml' }

      subject(:returned_status) { Nokogiri::XML(response.body).xpath('//message/status').text }

      context 'message exists' do
        specify { expect(response.status).to eq(200) }
        specify { expect(returned_status).to eq(status) }
      end

      context "message doesn't exist" do
        subject(:response) { get "/messages/notandid/status/#{format}" }
        specify { expect(response.status).to eq(400) }
      end
    end

    context 'other' do
      let(:format) { 'csv' }
      specify { expect(response.status).to eq(400) }
    end

  end
end
