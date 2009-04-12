# == Schema Information
# Schema version: 20090324042916
#
# Table name: users
#
#  id                        :integer(4)      not null, primary key
#  login                     :string(40)
#  name                      :string(100)     default("")
#  email                     :string(100)
#  crypted_password          :string(40)
#  salt                      :string(40)
#  created_at                :datetime
#  updated_at                :datetime
#  remember_token            :string(40)
#  remember_token_expires_at :datetime
#  activation_code           :string(40)
#  activated_at              :datetime
#  state                     :string(18)      default("passive"), not null
#  deleted_at                :datetime
#

require File.dirname(__FILE__) + '/../test_helper'
class UserTest < ActiveSupport::TestCase
  
  def setup
    # Build user and store in DB by default
    # Individual tests can override and use non-saved user if necessary
    @user = Factory(:user)
  end
  
  def new_user
    @user = User.new
  end
  def with_password
    @user.password = "testing"
    @user.password_confirmation = "testing"
  end
  def authenticate
    User.authenticate(@user.login, @user.password)
  end
  def invalid_authenticate
    User.authenticate(@user.login + "INVALID", @user.password + "INVALID")
  end
  
  should_validate_uniqueness_of :email, :login
  should_validate_presence_of :email, :state
  
  context "when first created" do
    setup {new_user}
    
    should "start in a passive state" do
      @user.passive?.should == true
    end
    should "not be able to register" do
      @user.can_register?.should == false
    end
    should "be able to register with a password" do
      with_password
      @user.can_register?.should == true
    end
  end
  
  context "when registered" do
    setup {[@user = Factory(:new_user), @user.register]}
    should "be pending" do
      @user.pending?.should be true
    end
    should "have activation_code" do
      @user.activation_code.should_not be nil
    end
  end
  
  context "when activated" do
    setup {[@user = Factory(:new_user), @user.register, @user.activate]}
    should "have activated_at timestamp" do
      @user.activated_at.should_not be nil
    end
    should "not have deleted_at timestamp" do
      @user.deleted_at.should be nil
    end
    should "be recently activated" do
      @user.recently_activated?.should be true
    end
  end
  
  context "when deleted" do
    setup {[@user = Factory(:user), @user.delete]}
    should "not authenticate" do
      authenticate.should be nil
    end
    should "have deleted_at timestamp" do
      @user.deleted_at.should_not be nil
    end
  end
  
  def check_token_set
    @user.remember_token.should_not be nil
    @user.remember_token_expires_at.should_not be nil
  end
  def check_token_unset
    @user.remember_token.should be nil
    @user.remember_token_expires_at.should be nil
  end
  
  context "remember me" do
    should "remember me" do
      @user.remember_me
      check_token_set
    end
    should "forget me" do
      @user.remember_me
      check_token_set
      @user.forget_me
      check_token_unset
    end

    should "remember me for one week" do
      # Use before and after dates to avoid problem where the token timestamp is a few miliseconds off our timestamp
      before = 1.week.from_now.utc
      @user.remember_me_for 1.week
      after = 1.week.from_now.utc
      check_token_set
      @user.remember_token_expires_at.between?(before, after).should be true
    end
    should "remember me until one week" do
      time = 1.week.from_now.utc
      @user.remember_me_until time
      check_token_set
      @user.remember_token_expires_at.should == time
    end
    should "remember me for two weeks by default" do
      before = 2.week.from_now.utc
      @user.remember_me
      after = 2.week.from_now.utc
      check_token_set
      @user.remember_token_expires_at.between?(before, after).should be true
    end
  end
  
  should "create valid user" do
    newuser = Factory.build(:new_user)
    newuser.valid?.should be true
    assert_difference 'User.count', 1 do
      assert_save newuser
    end
    newuser.created_at.should_not be nil
  end
  
  should "authenticate with login" do
    authenticate.should eql @user
  end
  
  should "authenticate with email" do
    User.authenticate(@user.email, @user.password).should eql @user
  end
  
  should "not authenticate with invalid credentials" do
    invalid_authenticate.should be nil
  end
  
  should "encrypt password" do
    newuser = Factory.build(:user)
    newuser.encrypt_password
    newuser.salt.should_not be nil
    newuser.crypted_password.should_not be nil
  end
  
  should "not store plain-text password when saved" do
    newuser = Factory.build(:user)
    assert_save newuser
    # Load object directly from DB
    userdb = User.find(newuser.id)
    userdb.password.should be nil
    userdb.salt.should_not be nil
    userdb.crypted_password.should_not be nil
  end
  
  should "reset password" do
    @user.update_attributes(:password => 'new password', :password_confirmation => 'new password')
    User.authenticate(@user.login, 'new password').should eql @user
  end
  
  should "not rehash password when login changes" do
    @user.update_attributes(:login => 'newlogin')
    User.authenticate('newlogin', @user.password).should eql @user
  end
end
