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
  f.state { User.state_machine.state(:active).value }
  f.activated_at 5.days.ago
end

Factory.define :new_user, :parent => :user do |f|
  f.state { User.state_machine.state(:passive).value }
  f.activated_at nil
end