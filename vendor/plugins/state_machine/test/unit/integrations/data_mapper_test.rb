require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

begin
  # Load library
  require 'rubygems'
  
  gem 'dm-core', ENV['DM_VERSION'] ? "=#{ENV['DM_VERSION']}" : '>=0.9.0'
  require 'dm-core'
  
  # Establish database connection
  DataMapper.setup(:default, 'sqlite3::memory:')
  DataObjects::Sqlite3.logger = DataObjects::Logger.new("#{File.dirname(__FILE__)}/../../data_mapper.log", :info)
  
  module DataMapperTest
    class BaseTestCase < Test::Unit::TestCase
      def default_test
      end
      
      protected
        # Creates a new DataMapper resource (and the associated table)
        def new_resource(auto_migrate = true, &block)
          resource = Class.new do
            include DataMapper::Resource
            
            storage_names[:default] = 'foo'
            def self.name; 'DataMapperTest::Foo'; end
            
            property :id, Integer, :serial => true
            property :state, String
            
            auto_migrate! if auto_migrate
          end
          resource.class_eval(&block) if block_given?
          resource
        end
        
        # Creates a new DataMapper observer
        def new_observer(resource, &block)
          observer = Class.new do
            include DataMapper::Observer
          end
          observer.observe(resource)
          observer.class_eval(&block) if block_given?
          observer
        end
    end
    
    class IntegrationTest < BaseTestCase
      def test_should_match_if_class_inherits_from_active_record
        assert StateMachine::Integrations::DataMapper.matches?(new_resource)
      end
      
      def test_should_not_match_if_class_does_not_inherit_from_active_record
        assert !StateMachine::Integrations::DataMapper.matches?(Class.new)
      end
    end
    
    class MachineByDefaultTest < BaseTestCase
      def setup
        @resource = new_resource
        @machine = StateMachine::Machine.new(@resource)
      end
      
      def test_should_use_save_as_action
        assert_equal :save, @machine.action
      end
      
      def test_should_not_use_transactions
        assert_equal false, @machine.use_transactions
      end
    end
    
    class MachineTest < BaseTestCase
      def setup
        @resource = new_resource
        @machine = StateMachine::Machine.new(@resource)
        @machine.state :parked, :idling, :first_gear
      end
      
      def test_should_create_singular_with_scope
        assert @resource.respond_to?(:with_state)
      end
      
      def test_should_only_include_records_with_state_in_singular_with_scope
        parked = @resource.create :state => 'parked'
        idling = @resource.create :state => 'idling'
        
        assert_equal [parked], @resource.with_state(:parked)
      end
      
      def test_should_create_plural_with_scope
        assert @resource.respond_to?(:with_states)
      end
      
      def test_should_only_include_records_with_states_in_plural_with_scope
        parked = @resource.create :state => 'parked'
        idling = @resource.create :state => 'idling'
        
        assert_equal [parked, idling], @resource.with_states(:parked, :idling)
      end
      
      def test_should_create_singular_without_scope
        assert @resource.respond_to?(:without_state)
      end
      
      def test_should_only_include_records_without_state_in_singular_without_scope
        parked = @resource.create :state => 'parked'
        idling = @resource.create :state => 'idling'
        
        assert_equal [parked], @resource.without_state(:idling)
      end
      
      def test_should_create_plural_without_scope
        assert @resource.respond_to?(:without_states)
      end
      
      def test_should_only_include_records_without_states_in_plural_without_scope
        parked = @resource.create :state => 'parked'
        idling = @resource.create :state => 'idling'
        first_gear = @resource.create :state => 'first_gear'
        
        assert_equal [parked, idling], @resource.without_states(:first_gear)
      end
      
      def test_should_allow_chaining_scopes
        parked = @resource.create :state => 'parked'
        idling = @resource.create :state => 'idling'
        
        assert_equal [idling], @resource.without_state(:parked).with_state(:idling)
      end
      
      def test_should_not_rollback_transaction_if_false
        @machine.within_transaction(@resource.new) do
          @resource.create
          false
        end
        
        assert_equal 1, @resource.all.size
      end
      
      def test_should_not_rollback_transaction_if_true
        @machine.within_transaction(@resource.new) do
          @resource.create
          true
        end
        
        assert_equal 1, @resource.all.size
      end
      
      def test_should_not_override_the_column_reader
        record = @resource.new
        record.attribute_set(:state, 'parked')
        assert_equal 'parked', record.state
      end
      
      def test_should_not_override_the_column_writer
        record = @resource.new
        record.state = 'parked'
        assert_equal 'parked', record.attribute_get(:state)
      end
    end
    
    class MachineUnmigratedTest < BaseTestCase
      def setup
        @resource = new_resource(false)
      end
      
      def test_should_allow_machine_creation
        assert_nothing_raised { StateMachine::Machine.new(@resource) }
      end
    end
    
    class MachineWithInitialStateTest < BaseTestCase
      def setup
        @resource = new_resource
        @machine = StateMachine::Machine.new(@resource, :initial => 'parked')
        @record = @resource.new
      end
      
      def test_should_set_initial_state_on_created_object
        assert_equal 'parked', @record.state
      end
    end
    
    class MachineWithNonColumnStateAttributeUndefinedTest < BaseTestCase
      def setup
        @resource = new_resource do
          def initialize
            # Skip attribute initialization
          end
        end
        
        @machine = StateMachine::Machine.new(@resource, :status, :initial => 'parked')
        @record = @resource.new
      end
      
      def test_should_define_a_new_property_for_the_attribute
        assert_not_nil @resource.properties[:status]
        assert @record.respond_to?(:status)
        assert @record.respond_to?(:status=)
      end
    end
    
    class MachineWithComplexPluralizationTest < BaseTestCase
      def setup
        @resource = new_resource
        @machine = StateMachine::Machine.new(@resource, :status)
      end
      
      def test_should_create_singular_with_scope
        assert @resource.respond_to?(:with_status)
      end
      
      def test_should_create_plural_with_scope
        assert @resource.respond_to?(:with_statuses)
      end
    end
    
    class MachineWithNonColumnStateAttributeDefinedTest < BaseTestCase
      def setup
        @resource = new_resource do
          attr_accessor :status
        end
        
        @machine = StateMachine::Machine.new(@resource, :status, :initial => 'parked')
        @record = @resource.new
      end
      
      def test_should_set_initial_state_on_created_object
        assert_equal 'parked', @record.status
      end
    end
    
    class MachineWithCallbacksTest < BaseTestCase
      def setup
        @resource = new_resource
        @machine = StateMachine::Machine.new(@resource)
        @machine.state :parked, :idling
        @machine.event :ignite
        @record = @resource.new(:state => 'parked')
        @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
      end
      
      def test_should_run_before_callbacks
        called = false
        @machine.before_transition(lambda {called = true})
        
        @transition.perform
        assert called
      end
      
      def test_should_pass_transition_to_before_callbacks_with_one_argument
        transition = nil
        @machine.before_transition(lambda {|arg| transition = arg})
        
        @transition.perform
        assert_equal @transition, transition
      end
      
      def test_should_pass_transition_to_before_callbacks_with_multiple_arguments
        callback_args = nil
        @machine.before_transition(lambda {|*args| callback_args = args})
        
        @transition.perform
        assert_equal [@transition], callback_args
      end
      
      def test_should_run_before_callbacks_within_the_context_of_the_record
        context = nil
        @machine.before_transition(lambda {context = self})
        
        @transition.perform
        assert_equal @record, context
      end
      
      def test_should_run_after_callbacks
        called = false
        @machine.after_transition(lambda {called = true})
        
        @transition.perform
        assert called
      end
      
      def test_should_pass_transition_to_after_callbacks_with_multiple_arguments
        callback_args = nil
        @machine.after_transition(lambda {|*args| callback_args = args})
        
        @transition.perform
        assert_equal [@transition], callback_args
      end
      
      def test_should_run_after_callbacks_with_the_context_of_the_record
        context = nil
        @machine.after_transition(lambda {context = self})
        
        @transition.perform
        assert_equal @record, context
      end
      
      def test_should_allow_symbolic_callbacks
        callback_args = nil
        
        klass = class << @record; self; end
        klass.send(:define_method, :after_ignite) do |*args|
          callback_args = args
        end
        
        @machine.before_transition(:after_ignite)
        
        @transition.perform
        assert_equal [@transition], callback_args
      end
      
      def test_should_allow_string_callbacks
        class << @record
          attr_reader :callback_result
        end
        
        @machine.before_transition('@callback_result = [1, 2, 3]')
        @transition.perform
        
        assert_equal [1, 2, 3], @record.callback_result
      end
    end
    
    begin
      gem 'dm-observer', ENV['DM_VERSION'] ? "=#{ENV['DM_VERSION']}" : '>=0.9.0'
      require 'dm-observer'
      
      class MachineWithObserversTest < BaseTestCase
        def setup
          @resource = new_resource
          @machine = StateMachine::Machine.new(@resource)
          @machine.state :parked, :idling
          @machine.event :ignite
          @record = @resource.new(:state => 'parked')
          @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
        end
        
        def test_should_provide_matcher_helpers
          matchers = []
          
          new_observer(@resource) do
            matchers = [all, any, same]
          end
          
          assert_equal [StateMachine::AllMatcher.instance, StateMachine::AllMatcher.instance, StateMachine::LoopbackMatcher.instance], matchers
        end
        
        def test_should_call_before_transition_callback_if_requirements_match
          called = false
          
          observer = new_observer(@resource) do
            before_transition :from => :parked do
              called = true
            end
          end
          
          @transition.perform
          assert called
        end
        
        def test_should_not_call_before_transition_callback_if_requirements_do_not_match
          called = false
          
          observer = new_observer(@resource) do
            before_transition :from => :idling do
              called = true
            end
          end
          
          @transition.perform
          assert !called
        end
        
        def test_should_pass_transition_to_before_callbacks
          callback_args = nil
          
          observer = new_observer(@resource) do
            before_transition do |*args|
              callback_args = args
            end
          end
          
          @transition.perform
          assert_equal [@transition], callback_args
        end
        
        def test_should_call_after_transition_callback_if_requirements_match
          called = false
          
          observer = new_observer(@resource) do
            after_transition :from => :parked do
              called = true
            end
          end
          
          @transition.perform
          assert called
        end
        
        def test_should_not_call_after_transition_callback_if_requirements_do_not_match
          called = false
          
          observer = new_observer(@resource) do
            after_transition :from => :idling do
              called = true
            end
          end
          
          @transition.perform
          assert !called
        end
        
        def test_should_pass_transition_to_after_callbacks
          callback_args = nil
          
          observer = new_observer(@resource) do
            after_transition do |*args|
              callback_args = args
            end
          end
          
          @transition.perform
          assert_equal [@transition], callback_args
        end
        
        def test_should_raise_exception_if_targeting_invalid_machine
          assert_raise(RUBY_VERSION < '1.9' ? IndexError : KeyError) do
            new_observer(@resource) do
              before_transition :invalid, :from => :parked do
              end
            end
          end
        end
        
        def test_should_allow_targeting_specific_machine
          @second_machine = StateMachine::Machine.new(@resource, :status)
          @resource.auto_migrate!
          
          called_state = false
          called_status = false
          
          observer = new_observer(@resource) do
            before_transition :state, :from => :parked do
              called_state = true
            end
            
            before_transition :status, :from => :parked do
              called_status = true
            end
          end
          
          @transition.perform
          
          assert called_state
          assert !called_status
        end
        
        def test_should_allow_targeting_multiple_specific_machines
          @second_machine = StateMachine::Machine.new(@resource, :status)
          @second_machine.state :parked, :idling
          @second_machine.event :ignite
          @resource.auto_migrate!
          
          called_attribute = nil
          
          attributes = []
          observer = new_observer(@resource) do
            before_transition :state, :status, :from => :parked do |transition|
              called_attribute = transition.attribute
            end
          end
          
          @transition.perform
          assert_equal :state, called_attribute
          
          StateMachine::Transition.new(@record, @second_machine, :ignite, :parked, :idling).perform
          assert_equal :status, called_attribute
        end
      end
      
      class MachineWithMixedCallbacksTest < BaseTestCase
        def setup
          @resource = new_resource
          @machine = StateMachine::Machine.new(@resource)
          @machine.state :parked, :idling
          @machine.event :ignite
          @record = @resource.new(:state => 'parked')
          @transition = StateMachine::Transition.new(@record, @machine, :ignite, :parked, :idling)
          
          @notifications = notifications = []
          
          # Create callbacks
          @machine.before_transition(lambda {notifications << :callback_before_transition})
          @machine.after_transition(lambda {notifications << :callback_after_transition})
          
          observer = new_observer(@resource) do
            before_transition do
              notifications << :observer_before_transition
            end
            
            after_transition do
              notifications << :observer_after_transition
            end
          end
          
          @transition.perform
        end
        
        def test_should_invoke_callbacks_in_specific_order
          expected = [
            :callback_before_transition,
            :observer_before_transition,
            :callback_after_transition,
            :observer_after_transition
          ]
          
          assert_equal expected, @notifications
        end
      end
    rescue LoadError
      $stderr.puts "Skipping DataMapper Observer tests. `gem install dm-observer#{" -v #{ENV['DM_VERSION']}" if ENV['DM_VERSION']}` and try again."
    end
    
    begin
      gem 'dm-validations', ENV['DM_VERSION'] ? "=#{ENV['DM_VERSION']}" : '>=0.9.0'
      require 'dm-validations'
      
      class MachineWithValidationsTest < BaseTestCase
        def setup
          @resource = new_resource
          @machine = StateMachine::Machine.new(@resource)
          @machine.state :parked
        end
        
        def test_should_invalidate_using_errors
          record = @resource.new
          record.state = 'parked'
          
          @machine.invalidate(record, :state, :invalid_transition, [[:event, :park]])
          
          assert_equal ['cannot transition via "park"'], record.errors.on(:state)
        end
        
        def test_should_clear_errors_on_reset
          record = @resource.new
          record.state = 'parked'
          record.errors.add(:state, 'is invalid')
          
          @machine.reset(record)
          assert_nil record.errors.on(:id)
        end
      end
      
      class MachineWithStateDrivenValidationsTest < BaseTestCase
        def setup
          @resource = new_resource do
            attr_accessor :seatbelt
          end
          
          @machine = StateMachine::Machine.new(@resource)
          @machine.state :first_gear, :second_gear do
            validates_present :seatbelt
          end
          @machine.other_states :parked
        end
        
        def test_should_be_valid_if_validation_fails_outside_state_scope
          record = @resource.new(:state => 'parked', :seatbelt => nil)
          assert record.valid?
        end
        
        def test_should_be_invalid_if_validation_fails_within_state_scope
          record = @resource.new(:state => 'first_gear', :seatbelt => nil)
          assert !record.valid?
        end
        
        def test_should_be_valid_if_validation_succeeds_within_state_scope
          record = @resource.new(:state => 'second_gear', :seatbelt => true)
          assert record.valid?
        end
      end
      
      class MachineWithEventAttributesOnValidationTest < BaseTestCase
        def setup
          @resource = new_resource
          @machine = StateMachine::Machine.new(@resource)
          @machine.event :ignite do
            transition :parked => :idling
          end
          
          @record = @resource.new
          @record.state = 'parked'
          @record.state_event = 'ignite'
        end
        
        def test_should_fail_if_event_is_invalid
          @record.state_event = 'invalid'
          assert !@record.valid?
          assert_equal ['is invalid'], @record.errors.full_messages
        end
        
        def test_should_fail_if_event_has_no_transition
          @record.state = 'idling'
          assert !@record.valid?
          assert_equal ['cannot transition when idling'], @record.errors.full_messages
        end
        
        def test_should_be_successful_if_event_has_transition
          assert @record.valid?
        end
        
        def test_should_run_before_callbacks
          ran_callback = false
          @machine.before_transition { ran_callback = true }
          
          @record.valid?
          assert ran_callback
        end
        
        def test_should_persist_new_state
          @record.valid?
          assert_equal 'idling', @record.state
        end
        
        def test_should_not_run_after_callbacks
          ran_callback = false
          @machine.after_transition { ran_callback = true }
          
          @record.valid?
          assert !ran_callback
        end
      end
    rescue LoadError
      $stderr.puts "Skipping DataMapper Validation tests. `gem install dm-validations#{" -v #{ENV['DM_VERSION']}" if ENV['DM_VERSION']}` and try again."
    end
  end
rescue LoadError
  $stderr.puts "Skipping DataMapper tests. `gem install dm-core#{" -v #{ENV['DM_VERSION']}" if ENV['DM_VERSION']}`, `gem install cucumber rspec hoe launchy do_sqlite3` and try again."
end
