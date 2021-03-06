# encoding: UTF-8
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

ActiveRecord::Schema.define(:version => 20150226173541) do

  create_table "cities", :force => true do |t|
    t.string   "name"
    t.integer  "region_id"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
    t.string   "manager_email"
  end

  create_table "guests", :force => true do |t|
    t.string   "email"
    t.string   "phone"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
    t.string   "name"
    t.integer  "num_of_friends"
  end

  create_table "hosts", :force => true do |t|
    t.string   "email"
    t.string   "phone"
    t.string   "address"
    t.integer  "city_id"
    t.integer  "max_guests"
    t.text     "free_text"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
    t.string   "f_name"
    t.string   "l_name"
    t.boolean  "strangers"
    t.text     "status"
    t.string   "survivor_needed"
    t.string   "contact"
    t.text     "survivor_details"
    t.float    "lat"
    t.float    "lng"
  end

  create_table "invites", :force => true do |t|
    t.integer  "guest_id"
    t.integer  "host_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "regions", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

end
