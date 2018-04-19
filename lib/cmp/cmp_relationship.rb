# frozen_string_literal: true

# @relationships = [ relationship ]
# @person = {
#     'cmpid' -> `cmp_person`
# }
# loop through relationships
#
#   get Org viap CmpEntity
#
#   get person:
#     1) CmpEntity exists
#     2) Search for matching person
#     3) create new person
#
#   look for similar relationship)
#
#    1) look for CmpRelationship
#       if found, check for updates
#
#    2) look for similar relationships
#       if found, check for updates
#
#    3) create new relationship
#
#        also create CmpRelationship
module Cmp
  class CmpRelationship
    BOARD_INTS = [2, 3, 4, 5].to_set.freeze
    EXECUTIVE_INTS = [1, 2, 3, 4, 5].to_set.freeze

    attr_reader :attributes, :status
    delegate :[], :fetch, to: :attributes

    def initialize(attrs)
      @attributes = LsHash.new(attrs)
      # status indicating timeframe of relationships
      # possible values:
      #   :only_2015, :only_2016, :both_years, :change, :unknown
      @status = derive_status
      @affiliation_id = @attributes.fetch('cmpid')
      @cmp_org_id = @attributes.fetch('cmp_org_id')
      @cmp_person_id = @attributes.fetch('cmp_person_id')
      # @org = CmpEntity.find_by(cmp_id: fetch(:cmp_org_id))&.entity
    end

    def import!
      return if skip_import?
      Cmp.transaction do
        relationships.each do |attrs|
          if find_matching_relationship
            relationship = find_matching_relationship
          else
            relationship = new_relationship
          end

          relationship.update!(attrs)
        end
      end
    end

    def relationships
      if status_changed
        # this indiciates that a change in status occurs
        # meaning, we should create two relationships
        relationships_for_both_years
      else
        Array.wrap(relationship_attributes)
      end
    end

    private

    ##
    # Import helpers
    #

    def new_relationship
      Relationship.create!(category_id: Relationship::POSITION_CATEGORY,
                           entity: person_entity,
                           related: org_entity)
    end

    # --> <Relationship> | nil
    def find_matching_relationship
      # NOT YET IMPLEMENTED
    end

    def org_entity
      CmpEntity.find_by(cmp_id: @cmp_org_id, entity_type: :org).entity
    end

    def person_entity
      CmpEntity.find_by(cmp_id: @cmp_person_id, entity_type: :person).entity
    end

    def skip_import?
      if ::CmpRelationship.find_by(cmp_affiliation_id: @affiliation_id)&.relationship_id
        Rails.logger.warn "CMP Relationship #{@affiliation_id} has already been imported"
        return true
      end

      unless CmpEntity.exists?(cmp_id: @cmp_org_id)
        Rails.logger.warn "Cannot import #{@affiliation_id} because cmp org \##{@cmp_org_id} does not exist"
        return true
      end

      unless CmpEntity.exists?(cmp_id: @cmp_person_id)
        Rails.logger.warn "Cannot import #{@affiliation_id} because cmp org \##{@cmp_person_id} does not exist"
        return true
      end

      return false
    end

    ##
    # Relationship attribute helpers
    #
    def relationship_attributes
      {
        description1: description1,
        is_current: is_current,
        start_date: start_date,
        end_date: end_date,
        position_attributes: position_attributes
      }
    end

    def relationships_for_both_years
      [
        {
          description1: description1,
          is_current: false,
          start_date: start_date,
          end_date: '2015-00-00',
          position_attributes: {
            is_board: board_member?('2015'), is_executive: executive?('2015')
          }
        },
        {
          description1: description1,
          is_current: nil,
          start_date: '2016-00-00',
          end_date: nil,
          position_attributes: {
            is_board: board_member?('2016'), is_executive: executive?('2016')
          }
        }
      ]
    end

    def description1(job_title = nil)
      job_title = fetch('job_title', nil) if job_title.nil?
      standardized_position = fetch('standardized_position', nil)

      if job_title.present?
        return job_title if job_title.length <= 50
        return Regexp.new('(.*);').match(job_title)[1] if job_title.include? ';'
        return Regexp.new('(.*\)),').match(job_title)[1] if job_title.include? '),'
        return Regexp.new('(.*),').match(job_title)[1] if job_title.include? ','
        return Regexp.new('(.*)-').match(job_title)[1] if job_title.include? '-'
      end

      if standardized_position.present?
        return 'CEO' if standardized_position.include?('CEO')
        return 'CFO' if standardized_position.include?('CFO')
        return 'COO' if standardized_position.include?('COO')
        return 'CIO' if standardized_position.include?('CIO')
        return 'Secretary' if standardized_position.downcase.include?('secretary')
        return 'Treasurer' if standardized_position.downcase.include?('treasurer')
        return 'Comptroller' if standardized_position.include?('Comptroller')
        return 'Vice Chairman' if standardized_position.include?('Vice Chairman')
        return 'Partner' if standardized_position.include?('Partner')
        return standardized_position.delete('+').strip if standardized_position.length < 40
      end
    end

    def start_date
      if /^\d{4}$/.match? fetch('appointment_year', '')
        "#{fetch('appointment_year')}-00-00"
      elsif @status == :only_2016
        '2016-00-00'
      end
    end

    def end_date
      '2015-00-00' if @status == :only_2015
    end

    def is_current
      return false if @status == :only_2015
      return nil
    end

    def position_attributes
      year = @status == :only_2015 ? '2015' : '2016'
      {
        is_board: board_member?(year),
        is_executive: executive?(year)
      }
    end

    def status_changed
      return false unless @status == :change
      (board_member?('2015') != board_member?('2016')) || (executive?('2015') != executive?('2016'))
    end

    def board_member?(year)
      BOARD_INTS.include? fetch("board_status_#{year}").to_i
    end

    def executive?(year)
      EXECUTIVE_INTS.include? fetch("ex_status_#{year}").to_i
    end

    

    # 'human readable symbol for variable NewIn2016
    def derive_status
      case fetch('new_in_2016').to_i
      when 0
        :only_2015
      when 1
        :change
      when 2
        :only_2016
      when 8
        :both_years
      else
        :unknown
      end
    end
    
  end
end
