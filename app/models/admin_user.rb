class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :validatable

  # Define searchable attributes for Ransack (used by Active Admin)
  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "email", "id", "remember_created_at", "updated_at"]
  end

  # Define searchable associations for Ransack
  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
