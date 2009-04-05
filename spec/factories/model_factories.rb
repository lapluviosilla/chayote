Factory.sequence :login do |n|
  "john#{n}"
end
Factory.sequence :email do |n|
  "john#{n}@example.com"
end

Factory.define :user do |f|
  f.login { Factory.next(:login) }
  f.name "John Doe"
  f.email { Factory.next(:email) }
  f.password "testing"
  f.password_confirmation "testing"
  f.state :active
end