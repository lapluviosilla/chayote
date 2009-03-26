require 'digest/sha1'

class User < ActiveRecord::Base
  include Authentication
  include Authentication::ByPassword
  include Authentication::ByCookieToken
  #include Authorization::AasmRoles

  validates_presence_of     :login
  validates_length_of       :login,    :within => 3..40
  validates_uniqueness_of   :login
  validates_format_of       :login,    :with => Authentication.login_regex, :message => Authentication.bad_login_message

  validates_format_of       :name,     :with => Authentication.name_regex,  :message => Authentication.bad_name_message, :allow_nil => true
  validates_length_of       :name,     :maximum => 100

  validates_presence_of     :email
  validates_length_of       :email,    :within => 6..100 #r@a.wk
  validates_uniqueness_of   :email
  validates_format_of       :email,    :with => Authentication.email_regex, :message => Authentication.bad_email_message

  

  # HACK HACK HACK -- how to do attr_accessible from here?
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :email, :name, :password, :password_confirmation
  
  # Account status state machine
  state_machine :initial => :passive do
    
    after_transition :on => :register, :do => :make_activation_code
    after_transition :on => :activate, :do => :do_activate
    after_transition :on => :delete, :do => :do_delete
    
    event :register do
      # Change state to pending and send out activation code. Do not change states if password has not been set.
      transition :passive => :pending, :if => lambda {|u| !(u.crypted_password.blank? && u.password.blank?) }
    end
    
    # Activate user account with email activation code
    event :activate do
      transition :pending => :active
    end
    
    # Suspend user temporarily. User can't login while suspended. Suspended accounts can be unsuspended
    event :suspend do
      transition all - [:suspended, :deleted] => :suspended
    end
    
    # Delete user permanentely. User is kept in DB for history purposes.
    event :delete do
      transition all - :deleted => :deleted
    end
    
    event :unsuspend do
      transition :suspended => :active, :if => !@activated_at.blank?
      transition :suspended => :pending, :if => !@activation_code.blank?
    end
  end

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  #
  # uff.  this is really an authorization, not authentication routine.  
  # We really need a Dispatch Chain here or something.
  # This will also let us return a human error message.
  #
  def self.authenticate(login, password)
    return nil if login.blank? || password.blank?
    # Old code from AASM states. Keep for now.
    # u = find_in_state :first, :active, :conditions => {:login => login.downcase} # need to get the salt
    u = find(:first, :conditions => {:login => login.downcase, :state => :active})
    u && u.authenticated?(password) ? u : nil
  end
  
  def display_name
    return login if name.blank?
    name
  end

  def login=(value)
    write_attribute :login, (value ? value.downcase : nil)
  end

  def email=(value)
    write_attribute :email, (value ? value.downcase : nil)
  end
  
  def recently_activated?
    @activated
  end
  def do_delete
    self.deleted_at = Time.now.utc
  end
  def do_activate
    @activated = true
    self.activated_at = Time.now.utc
    self.deleted_at = self.activation_code = nil
  end

  protected
    
    def make_activation_code
        self.deleted_at = nil
        self.activation_code = self.class.make_token
    end


end
