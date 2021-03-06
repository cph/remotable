# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110507152635) do

  create_table "tenants", :force => true do |t|
    t.string   "slug"
    t.string   "name"
    t.integer  "remote_id"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "remote_updated_at"
    t.datetime "expires_at", :null => false
  end

  add_index "tenants", ["slug"], name: "index_tenants_on_slug", unique: true, using: :btree

end
