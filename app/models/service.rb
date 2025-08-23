class Service < ApplicationRecord
  belongs_to :user

  monetize :price_hour_cents

  include PgSearch::Model
  pg_search_scope :global_search,
  against: [ :categories, :subcategories, :name, :description ],
  associated_against: {
    user: [ :email ]
  },
  using: {
    tsearch: { prefix: true }
  }

end
