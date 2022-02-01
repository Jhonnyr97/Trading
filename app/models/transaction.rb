# frozen_string_literal: true

class Transaction < ApplicationRecord
  enum type_action: %i[buy sell charging withdraw]
end
