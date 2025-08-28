# frozen_string_literal: true
class RenameStartEndTimeToStartEndAtInSchedules < ActiveRecord::Migration[7.1]
  def change
    # no-op: as colunas start_at/end_at já existem
  end
end
