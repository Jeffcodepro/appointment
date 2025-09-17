class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associações
  has_many :services, dependent: :destroy
  has_many_attached :images
  has_one_attached  :avatar
  has_one_attached  :banner
  has_one_attached  :pro_avatar   # 👈 foto específica para a visão Profissional
  has_many :messages, dependent: :destroy

  # Mantém enum legado (escopos etc.)
  enum role: { client: 0, professional: 1 }

  # ---------------- Geocoder ----------------
  geocoded_by :full_address
  before_validation :geocode, if: :should_geocode?

  BRAZIL_UF = %w[AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO].freeze

  # Garante nome preenchido no create (preenche a partir do e-mail se vier vazio)
  before_validation :ensure_name, on: :create
  validates :name, presence: true, on: :create

  # === NOVO: garantir que pelo menos um papel esteja habilitado (create/update)
  validate :at_least_one_role, on: [:create, :update]

  # === ALTERAÇÃO: validações de perfil PROFISSIONAL
  with_options if: :professional_on_create?, on: :create do
    validates :phone_number, :cep, :address, :address_number, :city, :state, :description, presence: true
    validates :state, inclusion: { in: BRAZIL_UF }
    validates :cep, format: { with: /\A\d{5}-?\d{3}\z/, message: "deve estar no formato 00000-000" }
    validates :phone_number, length: { minimum: 8 }
    validate  :must_be_geocoded, if: :geocoding_required?
  end

  with_options if: :validate_professional_on_update?, on: :update do
    validates :phone_number, :cep, :address, :address_number, :city, :state, :description, presence: true
    validates :state, inclusion: { in: BRAZIL_UF }
    validates :cep, format: { with: /\A\d{5}-?\d{3}\z/, message: "deve estar no formato 00000-000" }
    validates :phone_number, length: { minimum: 8 }
    validate  :must_be_geocoded, if: :geocoding_required?
  end


  before_validation :normalize_cep, if: -> { cep.present? && will_save_change_to_cep? }

  def full_address
    [address, address_number, city, state, cep, "Brasil"].compact_blank.join(", ")
  end

  # Visão atual na interface (multi-papéis)
  def acting_as
    active_role
  end

  # === ALTERAÇÃO: predicados refletem a VISÃO ATUAL
  def client?
    acting_as == "client"
  end

  def professional?
    acting_as == "professional"
  end

  # O usuário tem esse papel habilitado?
  def has_role?(role)
    role.to_s == "client" ? as_client : as_professional
  end

  # Habilita o papel (sem trocar a visão)
  def enable_role!(role)
    update!(role.to_s == "client" ? { as_client: true } : { as_professional: true })
  end

  # === ALTERAÇÃO: troca a visão SEM validar todo o perfil
  def switch_role!(role)
    r = role.to_s
    raise ArgumentError, "invalid role" unless %w[client professional].include?(r)
    enable_role!(r) unless has_role?(r)
    return true if r == active_role
    update_columns(active_role: r, updated_at: Time.current) # salva sem validações
  end


  def must_be_geocoded
    if latitude.blank? || longitude.blank?
      errors.add(:base, "Endereço inválido ou não geocodificado. Verifique CEP, rua, número, cidade e estado.")
    end
  end

  def inject_coordinates
    lat, long = self.geocode
    self.latitude = lat
    self.longitude = long
    self.save!
  end

  # Para usar nas views sem quebrar quando name está ausente
  def display_first_name
    (name.presence || email).to_s.split(/\s+/).first.to_s
  end

  private

  def ensure_name
    self.name = email.to_s.split("@").first if name.blank?
  end

  # === NOVO: validar ao menos um papel
  def at_least_one_role
    unless as_client || as_professional
      errors.add(:base, "Selecione pelo menos um perfil: Cliente e/ou Profissional.")
    end
  end

  # === NOVO: decide validação profissional no sign up
  def professional_on_create?
    as_professional || active_role.to_s == "professional"
  end

  def normalize_cep
    digits = cep.to_s.gsub(/\D/, "")
    self.cep = digits.size == 8 ? "#{digits[0..4]}-#{digits[5..7]}" : cep
  end

  def validate_professional_on_update?
    as_professional && changing_professional_fields?
  end

  def changing_professional_fields?
    will_save_change_to_phone_number? ||
    will_save_change_to_cep? ||
    will_save_change_to_address? ||
    will_save_change_to_address_number? ||
    will_save_change_to_city? ||
    will_save_change_to_state? ||
    will_save_change_to_description?
  end

  def changing_address_fields?
    will_save_change_to_address? ||
    will_save_change_to_address_number? ||
    will_save_change_to_city? ||
    will_save_change_to_state? ||
    will_save_change_to_cep?
  end

  def should_geocode?
    as_professional && changing_address_fields?
  end

  def geocoding_required?
    as_professional && changing_address_fields? &&
      (Rails.env.production? || ENV["MAPBOX_API_KEY"].present?)
  end

end
