# frozen_string_literal: true

class ListEntity < ApplicationRecord
  self.table_name = "ls_list_entity"
  include Api::Serializable
  include SoftDelete

  belongs_to :list, inverse_of: :list_entities
  belongs_to :entity, inverse_of: :list_entities

  def destroy
    soft_delete
  end

  private

  def after_soft_delete
    list.touch
  end

end
