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

  shared_examples 'it handles creating messages' do
    context 'valid params' do
      specify { expect(response.status).to eq(200) }
      specify { expect(@db).to have_message_record(id).with_attributes(:to_user, attributes[:to]) }
      specify { expect(@db).to have_message_record(id).with_attributes(:from_user, attributes[:from]) }
      specify { expect(@db).to have_message_record(id).with_attributes(:message, attributes[:message]) }
      specify do
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
      specify { expect(@db).not_to have_message_record }
      specify { expect(response.status).to eq(400) }
    end
  end

  shared_examples 'it handles getting message status' do
    context 'message exists' do
      specify { expect(response.status).to eq(200) }
      specify { expect(returned_status).to eq(status) }
    end

    context "message doesn't exist" do
      subject(:response) { get "/messages/notandid/status/#{format}" }
      specify { expect(response.status).to eq(400) }
    end
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
      it_behaves_like 'it handles creating messages'
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
      it_behaves_like 'it handles creating messages'
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
      it_behaves_like 'it handles getting message status'
    end

    context 'xml' do
      let(:format) { 'xml' }

      subject(:returned_status) { Nokogiri::XML(response.body).xpath('//message/status').text }
      it_behaves_like 'it handles getting message status'
    end

    context 'other' do
      let(:format) { 'csv' }
      specify { expect(response.status).to eq(400) }
    end

  end
end
