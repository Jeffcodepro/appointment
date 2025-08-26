class Service < ApplicationRecord
  belongs_to :user

  monetize :price_hour_cents

  CATEGORIES = ["Serviços Domésticos", "Reparos e Manutenção", "Saúde e Bem-Estar", "Aulas e Cursos", "Consultoria", "Eventos"]


  include PgSearch::Model
  pg_search_scope :global_search,
                  against: [:name, :description], # campos da service
                  associated_against: {
                    user: [:name, :city, :state]  # 👈 busca também no usuário
                  },
                  using: {
                    tsearch: { prefix: true }
                  }

  # 🔑 sempre incluir join de users
  scope :with_user, -> { joins(:user) }


end
