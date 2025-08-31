class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associações
  has_many :services, dependent: :destroy
  has_many_attached :images
  has_one_attached  :avatar
  has_one_attached  :banner

  # Papéis
  enum role: { client: 0, professional: 1 }

  # ---------------- Geocoder ----------------
  geocoded_by :full_address

  # antes: after_validation :geocode, if: :should_geocode?
  before_validation :geocode, if: :should_geocode?

  BRAZIL_UF = %w[AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO].freeze

  validates :name, presence: true, on: :create

  with_options if: :professional?, on: :update do
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

  def professional?
    role.to_s == "professional"
  end

  def should_geocode?
    professional? && (
      will_save_change_to_address? ||
      will_save_change_to_address_number? ||
      will_save_change_to_city? ||
      will_save_change_to_state? ||
      will_save_change_to_cep?
    )
  end

  def geocoding_required?
    # Exige geocoding em produção ou quando houver chave (para não travar no dev)
    professional? && (Rails.env.production? || ENV["MAPBOX_API_KEY"].present?)
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


  private

  def normalize_cep
    digits = cep.to_s.gsub(/\D/, "")
    self.cep = digits.size == 8 ? "#{digits[0..4]}-#{digits[5..7]}" : cep
  end
end
