require 'rails_helper'

describe 'Merging Entities' do
  describe 'initializing' do
    let(:source) { build(:org) }
    let(:dest) { build(:org) }

    it 'requires both source and dest entities' do
      expect { EntityMerger.new(source: source) }.to raise_error(ArgumentError)
      expect { EntityMerger.new(dest: dest) }.to raise_error(ArgumentError)
      expect { EntityMerger.new }.to raise_error(ArgumentError)
      expect { EntityMerger.new(source: source, dest: build(:document)) }.to raise_error(ArgumentError)
    end

    it 'sets source and dest attributes' do
      em = EntityMerger.new(source: source, dest: dest)
      expect(em.source).to eql source
      expect(em.dest).to eql dest
    end
  end

  it 'can only merge entities that have the same primary extension' do
    expect { EntityMerger.new source: build(:person), dest: build(:org) }.to raise_error(EntityMerger::ExtensionMismatchError)
  end
  
  
  it 'sets the "merged_id" fields of the merged entity to be the id of the merged entity'
  it 'marks the merged entity as deleted'


  context 'extensions' do
    let(:source_person) { create(:entity_person, :with_person_name) }
    let(:dest_person) { create(:entity_person, :with_person_name) }
    let(:source_org) { create(:entity_org, :with_org_name) }
    let(:dest_org) { create(:entity_org, :with_org_name) }
    subject { EntityMerger.new(source: source_person, dest: dest_person) } 

    context 'With no new extensions on the source' do
      it '@extensions contains non-new extension' do
        subject.merge_extensions
        expect(subject.extensions.length).to eql 1
        extension = subject.extensions.first
        expect(extension).to be_a EntityMerger::Extension
        expect(extension.new).to be false
        expect(extension.ext_id).to eql 1
        expect(extension.fields).to eql source_person.person.attributes.except('id', 'entity_id')
      end
    end

    context 'when the source has a new extension with fields' do
      before do
        source_person.add_extension('PoliticalCandidate') # ext_id = 3
        subject.merge_extensions
      end

      it 'has 2 extensions' do
        expect(subject.extensions.length).to eql 2
      end

      it 'has new extension' do
        new_ext = subject.extensions.select { |e| e.new == true }.first
        expect(new_ext.new).to be true
        expect(new_ext.ext_id).to eql 3
        expect(new_ext.fields.keys).to contain_exactly('is_federal', 'is_state', 'is_local', 'pres_fec_id', 'senate_fec_id', 'house_fec_id', 'crp_id') 
      end
    end


    context 'when the source has a new extension without fields' do
      subject { EntityMerger.new(source: source_org, dest: dest_org) }
      before do
        source_org.add_extension('Philanthropy') # ext_id = 9
        subject.merge_extensions
      end

      it { expect(subject.extensions.length).to eql 2 }

      it 'contains new philanthroy extension' do
        new_ext = subject.extensions.select { |e| e.new == true }.first
        expect(new_ext.ext_id).to eql 9
        expect(new_ext.fields).to eql({})
      end
    end

    it 'adds new extensions to the source' 
    it 'updates fields on the destination entity if they are nil'
  end

  context 'contact info' do
    it 'adds addresses to the destination entity'
    it 'adds emails to destination entity'
    it 'adds phone numbers to the destination entity'
  end

  context 'lists' do
    it 'adds the destination entity to the lists of the source entity'
    it 'removes the source entity from it\'s lists'
  end

  it 'transfers images from the source to the destination entity'

  it 'transfers aliases (if they do not already exist)'

  it 'transfers references'

  it 'transfers articles'

  context 'os donations' do
    it 'unmatches the os donations from the source entity'
    it 'matches those donations on the destination entity'
  end

  context 'ny donations' do
    it 'unmatches the ny donations from the source entity'
    it 'matches those donations on the destination entity'
  end

  context 'relationships' do
    context 'when a relationship exists on the source but not the destination' do
      it 'creates a new reference on the destination'
      it 'deletes the relationship from the source'
      it 'transfers the references from the relationship'
    end

    context 'when a relationship exists on both' do
      it 'does not create a new relationship'
      it 'deletes the relationship from the source'
      it 'updates fields on the existing relationship if the are null'
      it 'copies references from the source relationship'
    end
  end
end

