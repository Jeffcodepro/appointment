# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_09_06_205422) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_trgm"
  enable_extension "plpgsql"
  enable_extension "unaccent"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "professional_id", null: false
    t.bigint "service_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "professional_id", "service_id"], name: "idx_unique_conversation_triplet", unique: true
    t.index ["client_id"], name: "index_conversations_on_client_id"
    t.index ["professional_id"], name: "index_conversations_on_professional_id"
    t.index ["service_id"], name: "index_conversations_on_service_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "schedule_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "conversation_id"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["schedule_id"], name: "index_messages_on_schedule_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
    t.check_constraint "schedule_id IS NOT NULL OR conversation_id IS NOT NULL", name: "messages_has_parent"
  end

  create_table "schedules", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "service_id", null: false
    t.boolean "accepted_client"
    t.boolean "accepted_professional"
    t.boolean "confirmed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "start_at"
    t.datetime "end_at"
    t.integer "status", default: 0, null: false
    t.bigint "client_id", null: false
    t.bigint "professional_id", null: false
    t.integer "canceled_by"
    t.index ["canceled_by"], name: "index_schedules_on_canceled_by"
    t.index ["client_id"], name: "index_schedules_on_client_id"
    t.index ["professional_id"], name: "index_schedules_on_professional_id"
    t.index ["service_id"], name: "index_schedules_on_service_id"
    t.index ["status"], name: "index_schedules_on_status"
    t.index ["user_id"], name: "index_schedules_on_user_id"
  end

  create_table "services", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "categories"
    t.string "subcategories"
    t.decimal "price_hour"
    t.integer "average_hours"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "price_hour_cents", default: 0, null: false
    t.string "category"
    t.string "subcategory"
    t.index ["user_id"], name: "index_services_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.boolean "profile_completed", default: false, null: false
    t.string "name"
    t.string "cep"
    t.string "address"
    t.text "description"
    t.string "phone_number"
    t.float "latitude"
    t.float "longitude"
    t.string "address_number"
    t.string "city"
    t.string "state"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "conversations", "services"
  add_foreign_key "conversations", "users", column: "client_id"
  add_foreign_key "conversations", "users", column: "professional_id"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "schedules"
  add_foreign_key "messages", "users"
  add_foreign_key "schedules", "services"
  add_foreign_key "schedules", "users"
  add_foreign_key "schedules", "users", column: "client_id"
  add_foreign_key "schedules", "users", column: "professional_id"
  add_foreign_key "services", "users"
end
