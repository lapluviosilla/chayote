# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_chayote_session',
  :secret      => 'a5e5a8b41ed2aa6e95daa2d63193b16fe22a908770d79cc38be9ece6a11edc3d2bae79c0576a07a09168ed86601fbc5031d0d26bbbf47c1d4021b4dcec0f1d89'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
