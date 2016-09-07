require 'rails_helper'

describe Relationship, type: :model do
  before(:all) do 
    DatabaseCleaner.start
    Entity.skip_callback(:create, :after, :create_primary_ext)
    @loeb = create(:loeb)
    @nrsc = create(:nrsc)
    @loeb_donation = create(:loeb_donation, filings: 1, amount: 10000) # relationship model        
  end
  after(:all) do 
    Entity.set_callback(:create, :after, :create_primary_ext)
    DatabaseCleaner.clean
  end

  describe '#title' do 
    
    it 'returns description1 if it exists' do 
      rel = build(:position_relationship, description1: "dictator")
      expect(rel.title).to eql 'dictator'
    end

    it 'returns Board Member if the person is a board member' do 
       rel = create(:relationship, entity1_id: @loeb.id, entity2_id: @nrsc.id, category_id: 1)
       rel.position.update(is_board: true)
       expect(rel.title).to eql 'Board Member'
    end
    
    it 'returns "Member" if the position is a membership category' do 
      rel = create(:relationship, entity1_id: @loeb.id, entity2_id: @nrsc.id, category_id: 3)
      expect(rel.title).to eql 'Member'
    end

    it 'returns degree if Education description1 is blank and there is a degree id' do 
      rel = create(:relationship, entity1_id: @loeb.id, entity2_id: @nrsc.id, category_id: 2)
      rel.education.update(degree_id: 2)
      expect(rel.title).to eql 'Bachelor of Arts'
    end
    
  end


  describe 'Update Start/End dates' do 

    describe '#date_string_to_date' do 
      
      it 'returns nil if no date' do
        r = build(:loeb_donation, start_date: nil)
        expect(r.date_string_to_date(:start_date)).to be_nil
      end

      it 'returns nil if bad year' do
        r = build(:loeb_donation, start_date: "badd-00-00")
        expect(r.date_string_to_date(:start_date)).to be_nil
      end
      
      it 'converts "2012-00-00"' do 
        r = build(:loeb_donation)
        expect(r.date_string_to_date(:start_date)).to eq Date.new(2010)
      end

      it 'converts "2012-12-00"' do 
        r = build(:loeb_donation, start_date: "2012-12-00")
        expect(r.date_string_to_date(:start_date)).to eq Date.new(2012, 12)
      end

      it 'converts "2012-04-10"' do 
        r = build(:loeb_donation, start_date: "2012-4-10")
        expect(r.date_string_to_date(:start_date)).to eq Date.new(2012, 4, 10)
      end
      
    end
    
  end

  describe '#update_start_date_if_earlier' do
    it 'updates start date' do 
      @loeb_donation.update_start_date_if_earlier Date.new(1999)
      expect(@loeb_donation.start_date).to eql('1999-01-01')
    end 

    it 'updates end date' do 
      @loeb_donation.update_end_date_if_later Date.new(2012)
      expect(@loeb_donation.end_date).to eql('2012-01-01')
    end
    
    it 'does not change if not earlier' do 
      @loeb_donation.update_start_date_if_earlier Date.new(2010)
      expect(@loeb_donation.start_date).to eql('1999-01-01')
    end

    it 'does not change if not later' do 
      @loeb_donation.update_end_date_if_later Date.new(2010)
      expect(@loeb_donation.end_date).to eql('2012-01-01')
    end
  end

  describe '#update_contribution_info' do
    before(:all) do
      d1 = create(:loeb_donation_one)
      d2 = create(:loeb_donation_two)
      OsMatch.create!(relationship_id: @loeb_donation.id, os_donation_id: d1.id, donor_id: @loeb.id)
      OsMatch.create!(relationship_id: @loeb_donation.id, os_donation_id: d2.id, donor_id: @loeb.id)
      @loeb_donation.update_os_donation_info
    end
    
    it 'updates amount' do
      expect(@loeb_donation.amount).to eql 80800
    end

    it 'updates filing' do
      expect(@loeb_donation.filings).to eql 2
    end

    it 'does not update the database' do
      expect(Relationship.find(@loeb_donation).amount).not_to eql 80800
    end

    it 'can be chained with .save' do 
      @loeb_donation.update_os_donation_info.save
      expect(Relationship.find(@loeb_donation).amount).to eql 80800
    end

  end

  describe '#name' do
    it 'generates correct title for position relationship' do 
      rel = build(:relationship, category_id: 1, description1: 'boss')
      rel.position = build(:position, is_board: false)
      expect(rel.name).to eql "Position: Human Being, mega corp LLC"
    end
  end

  describe 'legacy_url' do 
    before(:all) do 
      @rel = build(:relationship, id: 1000)
    end
    
    it 'generates correct url' do 
      expect(@rel.legacy_url).to eql "/relationship/view/id/1000" 
    end
    
    it 'generates correct url with action' do 
      expect(@rel.legacy_url('edit')).to eql "/relationship/edit/id/1000" 
    end
  end

  describe '#details' do 
    describe 'it returns [ [field, value] ] for each Relationship type' do 
      it 'Position' do 
        rel = build(:relationship, category_id: 1, description1: 'boss', is_current: true)
        rel.position = build(:position, is_board: false)
        expect(rel.details).to eql [ ['Title', 'boss'], ['Is current', 'yes'], ['Board member', 'no'] ]
      end
      
    end
    
    
  end
  

end
