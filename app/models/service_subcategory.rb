class ServiceSubcategory < ApplicationRecord
  belongs_to :service, inverse_of: :service_subcategories

  monetize :price_hour_cents, allow_nil: true

  validates :name, presence: true
  validates :average_hours, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
