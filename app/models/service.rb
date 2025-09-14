# app/models/service.rb
class Service < ApplicationRecord
  belongs_to :user

  monetize :price_hour_cents
  has_many  :conversations, dependent: :destroy
  has_many  :service_subcategories, dependent: :destroy, inverse_of: :service
  accepts_nested_attributes_for :service_subcategories, allow_destroy: true

  validate :price_cap
  MAX_PRICE_CENTS = 100_000_000_00  # R$ 100.000.000,00

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

  CATEGORY_IMAGE = {
    "Salão de beleza"          => "servico_saude.png",
    "Fotografia"               => "servico_eventos.png",
    "Consultório odontológico" => "servico_saude.png",
    "Serviços domésticos"      => "servico_servicos_domesticos.png",
    "Pequenos reparos em casa" => "servico_reparo_manutencao.png"
  }.freeze

  include PgSearch::Model
  pg_search_scope :global_search,
    against: [:name, :description],
    associated_against: {
      user: [:name, :city, :state, :address, :address_number, :cep]
    },
    using: { tsearch: { prefix: true, any_word: true, dictionary: "portuguese" }, trigram: {} },
    ignoring: :accents

  scope :address_ilike, ->(q) {
    terms = q.to_s.downcase.scan(/[[:alnum:]]{2,}/)
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

  def self.fallback_image_for(category)
    CATEGORY_IMAGE[category] || "servico_reparo_manutencao.png"
  end

  # ==================== PREÇO: normalização segura ====================
  before_validation :normalize_price_fields
  validates :price_hour_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: false

  # Converte "100.000,00" / "100000,00" / "10000000" para CENTAVOS (Integer)
  def self.parse_to_cents(val)
    s = val.to_s
    digits = s.gsub(/\D/, "")
    return nil if digits.empty?

    if digits.length <= 2
      digits.to_i
    else
      cents   = digits[-2, 2].to_i
      reais_s = digits[0...-2]
      reais   = reais_s.present? ? reais_s.to_i : 0
      reais * 100 + cents
    end
  end

  private

  def normalize_price_fields
    if has_attribute?(:price_hour) && will_save_change_to_attribute?(:price_hour)
      parsed = Service.parse_to_cents(self[:price_hour])
      self.price_hour_cents = parsed if parsed
      self[:price_hour] = nil
    end

    if will_save_change_to_attribute?(:price_hour_cents)
      parsed = Service.parse_to_cents(self[:price_hour_cents])
      self[:price_hour_cents] = parsed if parsed
    end
  end

  def price_cap
    return if price_hour_cents.blank?
    if price_hour_cents > MAX_PRICE_CENTS
      errors.add(:price_hour, "Preço muito alto; máximo permitido é R$ 100.000.000,00")
    end
  end
end
