class AddStatusAndParticipantsToSchedules < ActiveRecord::Migration[7.1]
  def up
    # 1) Adiciona colunas (temporariamente permitindo NULL para backfill)
    add_column :schedules, :status, :integer, default: 0, null: false
    add_reference :schedules, :client, foreign_key: { to_table: :users }, null: true
    add_reference :schedules, :professional, foreign_key: { to_table: :users }, null: true

    # 2) Backfill: client_id <- user_id; professional_id <- services.user_id
    execute <<~SQL.squish
      UPDATE schedules AS s
      SET client_id = s.user_id,
          professional_id = srv.user_id
      FROM services AS srv
      WHERE srv.id = s.service_id
        AND (s.client_id IS NULL OR s.professional_id IS NULL);
    SQL

    # 3) Agora podemos exigir NOT NULL
    change_column_null :schedules, :client_id, false
    change_column_null :schedules, :professional_id, false

    # 4) Índice opcional para consultas por status
    add_index :schedules, :status
  end

  def down
    remove_index :schedules, :status
    remove_reference :schedules, :professional, foreign_key: true
    remove_reference :schedules, :client,       foreign_key: true
    remove_column :schedules, :status
  end
end
