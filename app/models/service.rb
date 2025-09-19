# app/models/service.rb
class Service < ApplicationRecord
  belongs_to :user

  # Imagem principal do serviço (usada nas listagens/show)
  has_one_attached :image

  # money-rails
  monetize :price_hour_cents

  has_many  :conversations, dependent: :destroy
  has_many  :service_subcategories, dependent: :destroy, inverse_of: :service
  accepts_nested_attributes_for :service_subcategories, allow_destroy: true

  # Limite (em centavos): R$ 100.000.000,00 -> 10_000_000_000
  MAX_PRICE_CENTS = 10_000_000_000

  # Acesso rápido ao banner do profissional (User deve ter has_one_attached :banner)
  delegate :banner, to: :user, prefix: true, allow_nil: true

  # ---------- Domínio ----------
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
    "Consultório odontológico" => "servico_odonto.png",
    "Serviços domésticos"      => "servico_servicos_domesticos.png",
    "Pequenos reparos em casa" => "servico_reparo_manutencao.png"
  }.freeze

  # ---------- Busca ----------
  include PgSearch::Model
  pg_search_scope :global_search,
    against: [:name, :description],
    associated_against: { user: [:name, :city, :state, :address, :address_number, :cep] },
    using: { tsearch: { prefix: true, any_word: true, dictionary: "portuguese" }, trigram: {} },
    ignoring: :accents

  scope :with_user, -> { joins(:user) }

  # busca direta por endereço (Rua/Av + número) com ILIKE e unaccent
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

  # ---------- Validações ----------
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :categories, inclusion: { in: CATEGORIES }
  validate  :subcategory_belongs_to_category
  validates :price_hour_cents, numericality: { greater_than_or_equal_to: 0 }
  validate  :price_cap

  # ---------- Callbacks ----------
  # Ao criar o serviço: se ele não tiver imagem, usa o banner do profissional
  after_commit :backfill_image_from_user_banner, on: :create

  # ---------- Helpers ----------
  def self.subcategories_for(category)
    SUBCATEGORIES[category] || []
  end

  # Tolerante a extensões/variações (servico_odonto*.{png,jpg,jpeg,webp})
  def self.fallback_image_for(category)
    @__fallback_cache ||= {}
    return @__fallback_cache[category] if @__fallback_cache.key?(category)

    base     = CATEGORY_IMAGE[category] || "servico_reparo_manutencao.png"
    basename = File.basename(base, File.extname(base))
    dir      = Rails.root.join("app/assets/images")

    varied = Dir.glob(dir.join("#{basename}*.{png,jpg,jpeg,webp}")).map { |p| File.basename(p) }.first
    found  = varied || (File.exist?(dir.join(base)) ? base : nil)

    @__fallback_cache[category] = found || "servico_reparo_manutencao.png"
  end

  # Fonte única para a view usar:
  # 1) image do serviço -> 2) banner do profissional -> 3) fallback por categoria
  def display_image
    return image if image.attached?
    return user_banner if user_banner&.attached?
    Service.fallback_image_for(categories) # retorna String (asset)
  end

  # --------- Parsing BR ("150,00") -> cents ---------
  # Permite enviar :price_hour como texto no formulário.
  def price_hour=(val)
    if val.is_a?(String)
      parsed = Service.parse_to_cents(val)
      if parsed
        self.price_hour_cents = parsed
      end
    end
    super
  end

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
      (reais * 100) + cents
    end
  end

  private

  def subcategory_belongs_to_category
    return if categories.blank? || subcategories.blank?
    allowed = Array(SUBCATEGORIES[categories])
    errors.add(:subcategories, "não é válida para a categoria selecionada") unless allowed.include?(subcategories)
  end

  def backfill_image_from_user_banner
    return if image.attached?
    return unless user_banner&.attached?
    image.attach(user_banner.blob) # referencia o mesmo blob (sem duplicar arquivo)
  end

  def price_cap
    return if price_hour_cents.blank?
    if price_hour_cents > MAX_PRICE_CENTS
      errors.add(:price_hour, "Preço muito alto; máximo permitido é R$ 100.000.000,00")
    end
  end
end
