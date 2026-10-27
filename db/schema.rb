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

ActiveRecord::Schema[8.1].define(version: 2026_10_27_102329) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "mail_folders", force: :cascade do |t|
    t.bigint "mailbox_id", null: false
    t.string "name", null: false
    t.bigint "uidvalidity"
    t.bigint "last_uid", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mailbox_id", "name"], name: "index_mail_folders_on_mailbox_id_and_name", unique: true
    t.index ["mailbox_id"], name: "index_mail_folders_on_mailbox_id"
  end

  create_table "mailboxes", force: :cascade do |t|
    t.string "provider", null: false
    t.string "address", null: false
    t.text "credentials"
    t.jsonb "sync_state", default: {}, null: false
    t.datetime "last_synced_at"
    t.text "last_sync_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "address"], name: "index_mailboxes_on_provider_and_address", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "mailbox_id", null: false
    t.bigint "mail_folder_id"
    t.string "provider_uid", null: false
    t.string "thread_key"
    t.string "message_id_header"
    t.string "subject"
    t.string "from_address"
    t.string "from_name"
    t.jsonb "to_addresses", default: [], null: false
    t.jsonb "cc_addresses", default: [], null: false
    t.datetime "sent_at"
    t.text "snippet"
    t.text "body_text"
    t.text "body_html"
    t.jsonb "labels", default: [], null: false
    t.integer "size"
    t.boolean "has_attachments", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mail_folder_id"], name: "index_messages_on_mail_folder_id"
    t.index ["mailbox_id", "provider_uid"], name: "index_messages_on_mailbox_id_and_provider_uid", unique: true
    t.index ["mailbox_id", "sent_at"], name: "index_messages_on_mailbox_id_and_sent_at"
    t.index ["mailbox_id", "thread_key"], name: "index_messages_on_mailbox_id_and_thread_key"
    t.index ["mailbox_id"], name: "index_messages_on_mailbox_id"
  end

  add_foreign_key "mail_folders", "mailboxes"
  add_foreign_key "messages", "mail_folders"
  add_foreign_key "messages", "mailboxes"
end
