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
    before(:each) {@user = Factory(:user, :state => :pending)}
  end
  describe "when suspended" do
    before(:each) {[@user = Factory(:user, :state => "active"), @user.suspend]}
    it "should not authenticate" do
      authenticate.should be nil
    end
  end
  describe "when deleted" do
    before(:each) {[@user = Factory(:user, :state => "active"), @user.delete]}
    it "should not authenticate" do
      authenticate.should be nil
    end
    it "should have deleted_at timestamp" do
      @user.deleted_at.should_not be nil
    end
  end
  
  it "should authenticate with valid credentials" do
    authenticate.should eql @user
  end
  
  it "should not authenticate with invalid credentials" do
    invalid_authenticate.should be nil
  end
  
end
