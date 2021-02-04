# frozen_string_literal: true

class Oligo < ApplicationRecord
  belongs_to :primer_set
  has_many :blast_hits

  def to_s
    "#{self.name}: #{self.sequence}"
  end
end
