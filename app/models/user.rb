class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  # attr_accessible :email, :password, :password_confirmation, :remember_me

  belongs_to :sf_guard_user, inverse_of: :user

  belongs_to :default_network, class_name: "List"
  belongs_to :sf_guard_user_profile, inverse_of: :user

  has_many :group_users, inverse_of: :user
  has_many :groups, through: :group_users, inverse_of: :users

  has_many :notes, inverse_of: :author

  has_many :note_users, inverse_of: :user
  has_many :received_notes, class_name: "Note", through: :note_users, inverse_of: :recipients

  def self.create_all_from_profiles
  	SfGuardUserProfiles.all.each { |p| p.create_user }
  end
end
