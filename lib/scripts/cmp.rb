require 'csv'

require Rails.root.join('lib', 'cmp.rb').to_s

# potential_matches_csv = "/littlesis/cmp/potential_cmp_matches.csv"
potential_matches_csv = Rails.root.join('data', 'potential_cmp_matches.csv')

print CSV.generate_line(%w[cmpid cmp_full_name entity_name entity_id entity_url entity_link_count cmp_relationships match_values])

def skip_entity?(entity, match_values)
  return true if match_values.include?('different_middle_name')
  return true if CmpEntity.exists?(entity_id: entity.id)
  return false if entity.link_count >= 10
  (match_values.include?('similar_first_name') || match_values.include?('same_first_name')) && match_values.include?('same_last_name')
end


CSV.foreach(potential_matches_csv, headers: true) do |row|
  if row['match_values'].nil?
    match_values = []
  else
    match_values = row['match_values'].split('|')
  end

  entity = Entity.find_by(id: row['match_id'])
  next if entity.nil?

  if skip_entity?(entity, match_values)
    # create new entity:
    # Cmp::Datasets.people[row['cmpid']].import!
    # Cmp::Datasets.people[row['cmpid']].clear_matches
  else
    csv_line = CSV.generate_line([
                                   row['cmpid'],
                                   row['fullname'],
                                   entity.name,
                                   entity.id,
                                   row['match_url'],
                                   entity.link_count,
                                   Cmp::Datasets
                                     .people[row['cmpid']]
                                     .cmp_relationships_with_title
                                     .join('|'),
                                   row['match_values']
                                 ])

    print csv_line
  end
end
