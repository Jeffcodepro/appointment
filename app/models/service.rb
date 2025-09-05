class Service < ApplicationRecord
  belongs_to :user

  monetize :price_hour_cents
  has_many :conversations, dependent: :destroy

  CATEGORIES = [
    "Salão de beleza",
    "Fotografia",
    "Consultório odontológico",
    "Serviços domésticos",
    "Pequenos reparos em casa"
  ].freeze

  SUBCATEGORIES = {
    "Salão de beleza" => [
      "Corte de cabelo", "Escova", "Coloração", "Manicure", "Pedicure",
      "Maquiagem", "Design de sobrancelhas"
    ],
    "Fotografia" => [
      "Ensaio externo", "Eventos", "Produtos", "Newborn", "Casamento",
      "Retrato corporativo"
    ],
    "Consultório odontológico" => [
      "Limpeza", "Clareamento dental", "Restauração", "Tratamento de canal",
      "Ortodontia", "Implante"
    ],
    "Serviços domésticos" => [
      "Faxina residencial", "Diarista", "Passadoria", "Organização",
      "Limpeza pós-obra"
    ],
    "Pequenos reparos em casa" => [
      "Eletricista", "Encanador", "Pintura", "Marido de aluguel",
      "Montagem de móveis", "Pequenos consertos"
    ]
  }.freeze

  include PgSearch::Model
  pg_search_scope :global_search,
    against: [:name, :description],
    associated_against: {
      user: [:name, :city, :state, :address, :address_number, :cep]
    },
    using: { tsearch: { prefix: true, any_word: true, dictionary: "portuguese" }, trigram: {} },
    ignoring: :accents

  # 👇 busca direta por endereço para pegar “Rua/Av + número” com ILIKE
  scope :address_ilike, ->(q) {
    terms = q.to_s.downcase.scan(/[[:alnum:]]{2,}/) # tokens com 2+ chars
    joins(:user).where(
      terms.map {
        "(unaccent(users.address) ILIKE unaccent(?) OR " \
        " unaccent(users.city)    ILIKE unaccent(?) OR " \
        " unaccent(users.state)   ILIKE unaccent(?) OR " \
        " users.cep               ILIKE ?)"
      }.join(" AND "),
      *terms.flat_map { |t| ["%#{t}%", "%#{t}%", "%#{t}%", "%#{t}%"] }
    )
  }

  scope :with_user, -> { joins(:user) }

end
