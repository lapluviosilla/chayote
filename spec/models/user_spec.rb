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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe User do
  
  before(:each) {@user = Factory(:user)}
  
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
  
  it { should validate_uniqueness_of :email }
  
  describe "when first created" do
    before(:each) {new_user}
    
    it "should start in a passive state" do
      @user.passive?.should == true
    end
    it "should not be able to register" do
      @user.can_register?.should == false
    end
    it "should be able to register with a password" do
      with_password
      @user.can_register?.should == true
    end
  end
  
  describe "when registered" do
    before(:each) {[@user = Factory(:new_user), @user.register]}
    it "should be pending" do
      @user.pending?.should be true
    end
    it "should have activation_code" do
      @user.activation_code.should_not be nil
    end
  end
  
  describe "when activated" do
    before(:each) {[@user = Factory(:new_user), @user.register, @user.activate]}
    it "should have activated_at timestamp" do
      @user.activated_at.should_not be nil
    end
    it "should not have deleted_at timestamp" do
      @user.deleted_at.should be nil
    end
    it "should be recently activated" do
      @user.recently_activated?.should be true
    end
  end
  
  describe "when suspended" do
    before(:each) {[@user = Factory(:user), @user.suspend]}
    it "should not authenticate" do
      authenticate.should be nil
    end
  end
  
  describe "when deleted" do
    before(:each) {[@user = Factory(:user), @user.delete]}
    it "should not authenticate" do
      authenticate.should be nil
    end
    it "should have deleted_at timestamp" do
      @user.deleted_at.should_not be nil
    end
  end
  
  describe "remember me" do
    def check_token_set
      @user.remember_token.should_not be nil
      @user.remember_token_expires_at.should_not be nil
    end
    def check_token_unset
      @user.remember_token.should be nil
      @user.remember_token_expires_at.should be nil
    end
    
    it "should remember me" do
      @user.remember_me
      check_token_set
    end

    it "should forget me" do
      @user.remember_me
      check_token_set
      @user.forget_me
      check_token_unset
    end

    it "should remember me for one week" do
      # Use before and after dates to avoid problem where the token timestamp is a few miliseconds off our timestamp
      before = 1.week.from_now.utc
      @user.remember_me_for 1.week
      after = 1.week.from_now.utc
      check_token_set
      @user.remember_token_expires_at.between?(before, after).should be true
    end
    it "should remember me until one week" do
      time = 1.week.from_now.utc
      @user.remember_me_until time
      check_token_set
      @user.remember_token_expires_at.should == time
    end
    it "should remember me for two weeks by default" do
      before = 2.week.from_now.utc
      @user.remember_me
      after = 2.week.from_now.utc
      check_token_set
      @user.remember_token_expires_at.between?(before, after).should be true
    end
  end
  
  it "should create valid user" do
    count = User.count
    newuser = Factory.build(:new_user)
    newuser.valid?.should be true
    newuser.save
    User.count.should == count + 1
    newuser.created_at.should_not be nil
  end
  
  it "should authenticate with valid credentials" do
    authenticate.should eql @user
  end
  
  it "should not authenticate with invalid credentials" do
    invalid_authenticate.should be nil
  end
  
  it "should reset password" do
    @user.update_attributes(:password => 'new password', :password_confirmation => 'new password')
    User.authenticate(@user.login, 'new password').should eql @user
  end
  
  it "should not rehash password when login changes" do
    @user.update_attributes(:login => 'newlogin')
    User.authenticate('newlogin', @user.password).should eql @user
  end
  
end
