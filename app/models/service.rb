class Service < ApplicationRecord
  belongs_to :user

  monetize :price_hour_cents
  has_many :conversations, dependent: :destroy

  CATEGORIES = [
    "Serviços Domésticos", "Reparos e Manutenção", "Saúde e Bem-Estar",
    "Aulas e Cursos", "Consultoria", "Eventos",
    "Serviços de Saúde e Estética", "Serviços Automotivos"
  ].freeze

  SUBCATEGORIES = {
    "Serviços Domésticos" => ["Limpeza", "Jardinagem", "Cozinhar"],
    "Reparos e Manutenção" => ["Elétrica", "Hidráulica", "Pintura", "Montagem de Móveis"],
    "Saúde e Bem-Estar" => ["Massagem", "Personal Trainer", "Fisioterapia"],
    "Aulas e Cursos" => ["Música", "Idiomas", "Artes Marciais"],
    "Consultoria" => ["Financeira", "Tecnológica", "Marketing"],
    "Eventos" => ["Fotografia", "Catering", "Decoração"],
    "Serviços de Saúde e Estética" => ["Dentista", "Cabeleireiro", "Barbeiro", "Manicure"],
    "Serviços Automotivos" => ["Mecânica", "Lavagem", "Funilaria", "Pintura"]
  }.freeze

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
