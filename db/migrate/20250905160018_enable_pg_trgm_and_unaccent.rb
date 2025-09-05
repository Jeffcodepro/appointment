
class EnablePgTrgmAndUnaccent < ActiveRecord::Migration[7.1]
  def change
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")
    enable_extension "unaccent" unless extension_enabled?("unaccent")
  end
end
