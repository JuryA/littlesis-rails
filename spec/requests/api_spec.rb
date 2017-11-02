require 'rails_helper'

describe Api do
  before(:all) do
    @user = create_really_basic_user
    @api_token = @user.create_api_token!
    @auth_header = { 'Littlesis-Api-Token': @api_token.token }
  end

  after(:all) do
    @user.sf_guard_user.delete
    @user.delete
    @api_token.delete
  end

  let(:meta) do
    {
      'copyright' => Api::META[:copyright],
      'license' => Api::META[:license],
      'apiVersion' => Api::META[:apiVersion]
    }
  end

  describe 'entities' do
    let(:lawyer) do
      create(:entity_person).tap { |e| e.add_extension('Lawyer') }
    end

    let(:expected) do
        {
          'data' => {
            'type' => 'entities',
            'id' => lawyer.id,
            'attributes' => {
              'name' => lawyer.name,
              'blurb' => lawyer.blurb,
              'primary_ext' => 'Person',
              'summary' => lawyer.summary,
              'parent_id' => nil,
              'website' => lawyer.website,
              'start_date' => lawyer.start_date,
              'end_date' => lawyer.end_date,
              'types' => ["Person", "Lawyer"],
              'aliases' => lawyer.aliases.map(&:name),
              'updated_at' => lawyer.updated_at.iso8601
            },
            'links' => { 'self' => Rails.application.routes.url_helpers.entity_url(lawyer) },
          },
          'meta' => meta
        }
      end

    describe 'entity information /entities/:id' do
      before { get api_entity_path(lawyer), {}, @auth_header }
      specify { expect(response).to have_http_status 200 }
      specify { expect(json).to eql(expected) }
    end

    describe 'request for details: /entities/:id?details=true' do
      let(:with_details) do
        expected.deep_merge('data' => { 'attributes' => {
                                          'extensions' => {
                                            "Person"=> {"name_last"=>"Being",
                                                        "name_first"=>"Human",
                                                        "name_middle"=>nil,
                                                        "name_prefix"=>nil,
                                                        "name_suffix"=>nil,
                                                        "name_nick"=>nil,
                                                        "birthplace"=>nil,
                                                        "gender_id"=>nil,
                                                        "party_id"=>nil,
                                                        "is_independent"=>nil,
                                                        "net_worth"=>nil,
                                                        "name_maiden"=>nil}}} })
      end
      
      before { get api_entity_path(lawyer), {'details' => 'true' }, @auth_header }
      specify { expect(response).to have_http_status 200 }
      specify { expect(json).to eql(with_details) }
    end

    describe 'record not found' do
      before { get api_entity_path(id: 1_000_000), {}, @auth_header }
      specify { expect(response).to have_http_status 404 }
      specify do
        expect(json).to eql({
                              'errors' => [ { 'title' => 'Record Missing' } ],
                              'meta' => meta
                            })
      end
    end

    describe 'record deleted' do
      before do
        deleted_pac = create(:pac, is_deleted: true)
        get api_entity_path(deleted_pac), {}, @auth_header 
      end
      specify { expect(response).to have_http_status 410 }
      specify do
        expect(json).to eql({
                              'errors' => [ { 'title' => 'Record Deleted' } ],
                              'meta' => meta
                            })
      end
    end
  end # end describe entiites

  describe '/entities/:id/extensions' do
    let(:entity) { create(:entity_org).tap { |e| e.add_extension('PoliticalFundraising') } } 
    let(:expected) do
      {
        'data' => [
          {
            'type' => 'extension-records',
            'id' => entity.extension_records.first.id,
            'attributes' => {
              "definition_id"=>2,
              "display_name"=>"Organization",
              "name"=>"Org"
            }
          },
          {
            'type' => 'extension-records',
            'id' => entity.extension_records.second.id,
            'attributes' => {
              "definition_id" => 11,
              "display_name" => "Political Fundraising Committee",
              "name"=>"PoliticalFundraising"
            }
          }
        ],
        'meta' => meta
      }
    end

    before { get extensions_api_entity_path(entity), {}, @auth_header } 
    specify { expect(response).to have_http_status 200 }
    specify { expect(json).to eql(expected) }
  end

  describe '/entities/search?q=NAME' do
    let(:entities) { TestSphinxResponse.new([build(:org), build(:person)]) }
    let(:mock_search) { double(:per => double(:page => entities)) }

    class TestSphinxResponse < Array
      def is_a?(klass)
        return true if klass == ThinkingSphinx::Search
        false
      end
      def current_page; 1 end
      def total_pages; 2 end
    end

    context 'missing param name' do
      before { get api_entities_search_path, {}, @auth_header }
      specify { expect(response).to have_http_status 400 }
    end

    context 'submission with param name' do
      before do
        expect(Entity::Search).to receive(:search).and_return(mock_search)
        get api_entities_search_path, {q: 'entity name' }, @auth_header
      end

      specify { expect(response).to have_http_status 200 }
      specify { expect(json['data']).to be_a Array }
      specify { expect(json['data'].length).to eql 2 }
      specify do
        expect(json['meta'])
          .to eql({
                    'copyright' => Api::META[:copyright],
                    'license' => Api::META[:license],
                    'apiVersion' => Api::META[:apiVersion],
                    'currentPage'=> 1,
                    'pageCount' => 2
                  })
      end

    end
  end

  describe '/relationships/:id' do
    let(:entity1) { create(:entity_person) }
    let(:entity2) { create(:entity_org) }
    let(:relationship) { Relationship.create!(category_id: 1, entity: entity1, related: entity2) }

    before { get api_relationship_path(relationship), {}, @auth_header }

    specify { expect(response).to have_http_status 200 }
    specify do
      expect(json).to eql({
                            'data' => relationship.api_data,
                            'meta' => meta,
                            'included' => [ entity1.api_data(exclude: :extensions), entity2.api_data(exclude: :extensions) ]
                          })
    end

  end
end
