class Link < ActiveRecord::Base
  include SingularTable

  belongs_to :relationship, inverse_of: :links
  belongs_to :entity, foreign_key: "entity1_id", inverse_of: :links
  belongs_to :related, class_name: "Entity", foreign_key: "entity2_id", inverse_of: :reverse_links
  has_many :chained_links, class_name: "Link", foreign_key: "entity1_id", primary_key: "entity2_id"

  def self.interlock_hash_from_entities(entity_ids)
    interlock_hash(where(entity1_id: entity_ids))
  end

  def self.interlock_hash(links)
    links.reduce({}) do |hash, link| 
      hash[link.entity2_id] = hash.fetch(link.entity2_id, []).push(link.entity1_id).uniq
      hash
    end
  end

  def position_type 
    return 'None' unless category_id == 1

    org_types = related.extension_names

    return 'business' if (org_types & ['Business', 'BusinessPerson']).any?
    return 'government' if org_types.include? 'GovernmentBody'
    return 'office' if (org_types & ['ElectedRepresentative', 'PublicOfficial']).any?
    return 'other'
  end
end