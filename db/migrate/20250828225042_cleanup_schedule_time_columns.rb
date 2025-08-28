class CleanupScheduleTimeColumns < ActiveRecord::Migration[7.1]
  def up
    # Remover colunas legadas, se ainda existirem
    remove_column :schedules, :start_time, :time if column_exists?(:schedules, :start_time)
    remove_column :schedules, :end_time,   :time if column_exists?(:schedules, :end_time)

    # Garantir que as colunas novas sejam datetime
    change_column :schedules, :start_at, :datetime if column_exists?(:schedules, :start_at)
    change_column :schedules, :end_at,   :datetime if column_exists?(:schedules, :end_at)
  end

  def down
    # Voltar (opcional): recria as colunas antigas como time
    add_column :schedules, :start_time, :time unless column_exists?(:schedules, :start_time)
    add_column :schedules, :end_time,   :time unless column_exists?(:schedules, :end_time)
    # Não dá para "des-converter" datetime em time com segurança aqui
  end
end
