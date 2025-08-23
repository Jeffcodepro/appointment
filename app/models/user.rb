class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many_attached :images
  enum role: { client: 0, professional: 1 }

  has_one_attached :avatar

  # No signup: queremos só o essencial (role, name, email, password)
  validates :name, presence: true, on: :create

  # Quando o PROFISSIONAL for completar/editar perfil:
  with_options if: :professional?, on: :update do
    validates :phone_number, :cep, :address, :description, presence: true
    validates :cep, format: { with: /\A\d{5}-?\d{3}\z/ }, allow_blank: true
    validates :phone_number, length: { minimum: 8 }, allow_blank: true
  end

  # Flag que controla se já completou o perfil
  # (já existe no schema: profile_completed:boolean)

  before_save :normalize_cep, if: -> { will_save_change_to_cep? && cep.present? }

  private

  def normalize_cep
    digits = cep.gsub(/\D/, '')
    self.cep = digits.size == 8 ? "#{digits[0..4]}-#{digits[5..7]}" : cep
  end
end
