require 'rails_helper'

describe EntityHistory do
  with_versioning do
    subject { EntityHistory.new(entity) }
    let(:person) { create(:entity_person) }

    describe 'object setup: entity internal attribute and delegation' do
      let(:entity) { build(:org) }
      specify { expect(subject.send(:entity)).to eql entity }
    end

    describe 'after entity has been created' do
      let!(:entity) { create(:entity_org) }
      subject { EntityHistory.new(entity) }
      specify { expect(subject.versions.length).to eql 1 }
      describe 'version of create event' do
        subject { EntityHistory.new(entity).versions.first }
        specify { expect(subject.event).to eql 'create' }
      end
    end

    describe 'versions includes relationships' do
      before do
        # create two relationships
        Relationship.create!(category_id: 1, entity: person, related: create(:entity_org))
        Relationship.create!(category_id: 12, entity: create(:entity_org), related: person)
      end
      subject(:versions) { EntityHistory.new(person).versions }

      it 'returns 3 versions' do
        expect(versions.total_count).to eql 3
      end

      it 'returns 2 relationship versions and 1 entity version' do
        expect(
          versions.select { |v| v.item_type == 'Entity' }.size
        ).to eql 1

        expect(
          versions.select { |v| v.item_type == 'Relationship' }.size
        ).to eql 2
      end
    end

    describe 'versions includes updates to extensions' do
      let(:entity) { create(:entity_org) }
      subject(:versions) { EntityHistory.new(entity).versions }

      before do
        entity.add_extension 'School'
        entity.school.update endowment: 1_000_000
      end

      specify { expect(versions.total_count).to eql 3 }

      specify do
        expect(versions.select { |v| v.item_type == 'ExtensionRecord' }.size).to eql 1
      end

      specify do
        expect(versions.select { |v| v.item_type == 'School' }.size).to eql 1
      end
    end

    describe 'versions includes user and entity attribute' do
      let(:user) { create_really_basic_user }
      let(:entity) { create(:entity_org) }
      subject(:versions) { EntityHistory.new(entity).versions }

      before { PaperTrail.whodunnit(user.id.to_s) { entity.add_extension 'School' } }
      specify { versions.each { |v| expect(v.user).to eql user } }
      specify { versions.each { |v| expect(v.entity).to eql entity } }
    end

    describe 'pagination' do
      before do
        # add two versions
        %w[MediaPersonality PublicIntellectual].each { |ext| person.add_extension ext }
      end

      context 'version count is under default per page limit' do
        subject { EntityHistory.new(person).versions.total_count }
        it { is_expected.to eql 3 }
      end

      context 'has 2 pages of results' do
        context 'requesting page 1' do
          subject { EntityHistory.new(person).versions(per_page: 2, page: 1) }
          specify { expect(subject.count).to eql 2 }
          specify { expect(subject.total_count).to eql 3 }
        end

        context 'requesting page 2' do
          subject { EntityHistory.new(person).versions(per_page: 2, page: 2) }
          specify { expect(subject.count).to eql 1 }
          specify { expect(subject.total_count).to eql 3 }
        end
      end
    end
  end
end

