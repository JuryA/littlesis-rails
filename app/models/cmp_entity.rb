# frozen_string_literal: true

class CmpEntity < ApplicationRecord
  belongs_to :entity
  enum entity_type: [:org, :person]
end
