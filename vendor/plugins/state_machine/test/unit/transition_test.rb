require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransitionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_have_an_object
    assert_equal @object, @transition.object
  end
  
  def test_should_have_a_machine
    assert_equal @machine, @transition.machine
  end
  
  def test_should_have_an_event
    assert_equal :ignite, @transition.event
  end
  
  def test_should_have_a_qualified_event
    assert_equal :ignite, @transition.qualified_event
  end
  
  def test_should_have_a_from_value
    assert_equal 'parked', @transition.from
  end
  
  def test_should_have_a_from_name
    assert_equal :parked, @transition.from_name
  end
  
  def test_should_have_a_qualified_from_name
    assert_equal :parked, @transition.qualified_from_name
  end
  
  def test_should_have_a_to_value
    assert_equal 'idling', @transition.to
  end
  
  def test_should_have_a_to_name
    assert_equal :idling, @transition.to_name
  end
  
  def test_should_have_a_qualified_to_name
    assert_equal :idling, @transition.qualified_to_name
  end
  
  def test_should_have_an_attribute
    assert_equal :state, @transition.attribute
  end
  
  def test_should_not_have_an_action
    assert_nil @transition.action
  end
  
  def test_should_generate_attributes
    expected = {:object => @object, :attribute => :state, :event => :ignite, :from => 'parked', :to => 'idling'}
    assert_equal expected, @transition.attributes
  end
  
  def test_should_not_have_any_args
    assert_nil @transition.args
  end
  
  def test_should_use_pretty_inspect
    assert_equal '#<StateMachine::Transition attribute=:state event=:ignite from="parked" from_name=:parked to="idling" to_name=:idling>', @transition.inspect
  end
end

class TransitionWithDynamicToValueTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked
    @machine.state :idling, :value => lambda {1}
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_evaluate_to_value
    assert_equal 1, @transition.to
  end
end

class TransitionWithNamespaceTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :namespace => 'alarm')
    @machine.state :off, :active
    @machine.event :activate
    
    @object = @klass.new
    @object.state = 'off'
    
    @transition = StateMachine::Transition.new(@object, @machine, :activate, :off, :active)
  end
  
  def test_should_have_an_event
    assert_equal :activate, @transition.event
  end
  
  def test_should_have_a_qualified_event
    assert_equal :activate_alarm, @transition.qualified_event
  end
  
  def test_should_have_a_from_name
    assert_equal :off, @transition.from_name
  end
  
  def test_should_have_a_qualified_from_name
    assert_equal :alarm_off, @transition.qualified_from_name
  end
  
  def test_should_have_a_to_name
    assert_equal :active, @transition.to_name
  end
  
  def test_should_have_a_qualified_to_name
    assert_equal :alarm_active, @transition.qualified_to_name
  end
end

class TransitionWithActionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      def save
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_have_an_action
    assert_equal :save, @transition.action
  end
end

class TransitionAfterBeingPersistedTest < Test::Unit::TestCase
  def setup
    @klass = Class.new
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @transition.persist
  end
  
  def test_should_update_state_value
    assert_equal 'idling', @object.state
  end
end

class TransitionWithCallbacksTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved, :save_state
      
      def save
        @save_state = state
        @saved = true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_run_before_callbacks_on_before
    @machine.before_transition(lambda {|object| @run = true})
    @transition.before
    
    assert_equal true, @run
  end
  
  def test_should_run_before_callbacks_in_the_order_they_were_defined
    @callbacks = []
    @machine.before_transition(lambda {@callbacks << 1})
    @machine.before_transition(lambda {@callbacks << 2})
    @transition.before
    
    assert_equal [1, 2], @callbacks
  end
  
  def test_should_only_run_before_callbacks_that_match_transition_context
    @count = 0
    callback = lambda {@count += 1}
    
    @machine.before_transition :from => :parked, :to => :idling, :on => :park, :do => callback
    @machine.before_transition :from => :parked, :to => :parked, :on => :park, :do => callback
    @machine.before_transition :from => :parked, :to => :idling, :on => :ignite, :do => callback
    @machine.before_transition :from => :idling, :to => :idling, :on => :park, :do => callback
    @transition.before
    
    assert_equal 1, @count
  end
  
  def test_should_pass_transition_to_before_callbacks
    @machine.before_transition(lambda {|*args| @args = args})
    @transition.before
    
    assert_equal [@object, @transition], @args
  end
  
  def test_should_not_catch_halted_before_callbacks
    @machine.before_transition(lambda {throw :halt})
    
    assert_throws(:halt) { @transition.before }
  end
  
  def test_should_run_before_callbacks_on_perform_before_changing_the_state
    @machine.before_transition(lambda {|object| @state = object.state})
    @transition.perform
    
    assert_equal 'parked', @state
  end
  
  def test_should_run_after_callbacks_on_after
    @machine.after_transition(lambda {|object| @run = true})
    @transition.after(true)
    
    assert_equal true, @run
  end
  
  def test_should_run_after_callbacks_in_the_order_they_were_defined
    @callbacks = []
    @machine.after_transition(lambda {@callbacks << 1})
    @machine.after_transition(lambda {@callbacks << 2})
    @transition.after(true)
    
    assert_equal [1, 2], @callbacks
  end
  
  def test_should_only_run_after_callbacks_that_match_transition_context
    @count = 0
    callback = lambda {@count += 1}
    
    @machine.after_transition :from => :parked, :to => :idling, :on => :park, :do => callback
    @machine.after_transition :from => :parked, :to => :parked, :on => :park, :do => callback
    @machine.after_transition :from => :parked, :to => :idling, :on => :ignite, :do => callback
    @machine.after_transition :from => :idling, :to => :idling, :on => :park, :do => callback
    @transition.after(true)
    
    assert_equal 1, @count
  end
  
  def test_should_pass_transition_and_action_result_to_after_callbacks
    @machine.after_transition(lambda {|*args| @args = args})
    
    @transition.after(true)
    assert_equal [@object, @transition, true], @args
    
    @transition.after(false)
    assert_equal [@object, @transition, false], @args
  end
  
  def test_should_catch_halted_after_callbacks
    @machine.after_transition(lambda {throw :halt})
    
    assert_nothing_thrown { @transition.after(true) }
  end
  
  def test_should_run_after_callbacks_on_perform_after_running_the_action
    @machine.after_transition(lambda {|object| @state = object.state})
    @transition.perform(true)
    
    assert_equal 'idling', @state
  end
end

class TransitionAfterBeingPerformedTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved, :save_state
      
      def save
        @save_state = state
        @saved = true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end
  
  def test_should_have_empty_args
    assert_equal [], @transition.args
  end
  
  def test_should_be_successful
    assert_equal true, @result
  end
  
  def test_should_change_the_current_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_run_the_action
    assert @object.saved
  end
  
  def test_should_run_the_action_after_saving_the_state
    assert_equal 'idling', @object.save_state
  end
end

class TransitionWithoutRunningActionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform(false)
  end
  
  def test_should_have_empty_args
    assert_equal [], @transition.args
  end
  
  def test_should_be_successful
    assert_equal true, @result
  end
  
  def test_should_change_the_current_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_not_run_the_action
    assert !@object.saved
  end
end

class TransitionWithPerformArgumentsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
  end
  
  def test_should_have_arguments
    @transition.perform(1, 2)
    
    assert_equal [1, 2], @transition.args
    assert @object.saved
  end
  
  def test_should_not_include_run_action_in_arguments
    @transition.perform(1, 2, false)
    
    assert_equal [1, 2], @transition.args
    assert !@object.saved
  end
end

class TransitionWithTransactionsTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      class << self
        attr_accessor :running_transaction
      end
      
      attr_accessor :result
      
      def save
        @result = self.class.running_transaction
        true
      end
    end
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    
    class << @machine
      def within_transaction(object)
        owner_class.running_transaction = object
        yield
        owner_class.running_transaction = false
      end
    end
  end
  
  def test_should_run_blocks_within_transaction_for_object
    @transition.within_transaction do
      @result = @klass.running_transaction
    end
    
    assert_equal @object, @result
  end
  
  def test_should_run_before_callbacks_within_transaction
    @machine.before_transition(lambda {|object| @result = @klass.running_transaction})
    @transition.perform
    
    assert_equal @object, @result
  end
  
  def test_should_run_action_within_transaction
    @transition.perform
    
    assert_equal @object, @object.result
  end
  
  def test_should_run_after_callbacks_within_transaction
    @machine.after_transition(lambda {|object| @result = @klass.running_transaction})
    @transition.perform
    
    assert_equal @object, @result
  end
end

class TransitionHaltedDuringBeforeCallbacksTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      class << self; attr_accessor :cancelled_transaction; end
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    @before_count = 0
    @after_count = 0
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    class << @machine
      def within_transaction(object)
        owner_class.cancelled_transaction = yield == false
      end
    end
    
    @machine.before_transition lambda {@before_count += 1; throw :halt}
    @machine.before_transition lambda {@before_count += 1}
    @machine.after_transition lambda {@after_count += 1}
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end
  
  def test_should_not_be_successful
    assert !@result
  end
  
  def test_should_not_change_current_state
    assert_equal 'parked', @object.state
  end
  
  def test_should_not_run_action
    assert !@object.saved
  end
  
  def test_should_not_run_further_before_callbacks
    assert_equal 1, @before_count
  end
  
  def test_should_not_run_after_callbacks
    assert_equal 0, @after_count
  end
  
  def test_should_cancel_the_transaction
    assert @klass.cancelled_transaction
  end
end

class TransitionHaltedDuringActionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      class << self; attr_accessor :cancelled_transaction; end
      attr_reader :saved
      
      def save
        throw :halt
      end
    end
    @before_count = 0
    @after_count = 0
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    class << @machine
      def within_transaction(object)
        owner_class.cancelled_transaction = yield == false
      end
    end
    
    @machine.before_transition lambda {@before_count += 1}
    @machine.after_transition lambda {@after_count += 1}
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end
  
  def test_should_not_be_successful
    assert !@result
  end
  
  def test_should_change_current_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_run_before_callbacks
    assert_equal 1, @before_count
  end
  
  def test_should_not_run_after_callbacks
    assert_equal 0, @after_count
  end
  
  def test_should_cancel_the_transaction
    assert @klass.cancelled_transaction
  end
end

class TransitionHaltedAfterCallbackTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      class << self; attr_accessor :cancelled_transaction; end
      attr_reader :saved
      
      def save
        @saved = true
      end
    end
    @before_count = 0
    @after_count = 0
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    class << @machine
      def within_transaction(object)
        owner_class.cancelled_transaction = yield == false
      end
    end
    
    @machine.before_transition lambda {@before_count += 1}
    @machine.after_transition lambda {@after_count += 1; throw :halt}
    @machine.after_transition lambda {@after_count += 1}
    
    @object = @klass.new
    @object.state = 'parked'
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end
  
  def test_should_be_successful
    assert @result
  end
  
  def test_should_change_current_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_run_before_callbacks
    assert_equal 1, @before_count
  end
  
  def test_should_not_run_further_after_callbacks
    assert_equal 1, @after_count
  end
  
  def test_should_not_cancel_the_transaction
    assert !@klass.cancelled_transaction
  end
end

class TransitionWithFailedActionTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      class << self; attr_accessor :cancelled_transaction; end
      attr_reader :saved
      
      def save
        false
      end
    end
    @before_count = 0
    @after_count = 0
    
    @machine = StateMachine::Machine.new(@klass, :action => :save)
    @machine.state :parked, :idling
    @machine.event :ignite
    class << @machine
      def within_transaction(object)
        owner_class.cancelled_transaction = yield == false
      end
    end
    
    @machine.before_transition lambda {@before_count += 1}
    @machine.after_transition lambda {@after_count += 1}
    
    @object = @klass.new
    @transition = StateMachine::Transition.new(@object, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end
  
  def test_should_not_be_successful
    assert !@result
  end
  
  def test_should_change_current_state
    assert_equal 'idling', @object.state
  end
  
  def test_should_run_before_callbacks
    assert_equal 1, @before_count
  end
  
  def test_should_run_after_callbacks
    assert_equal 1, @after_count
  end
  
  def test_should_cancel_the_transaction
    assert @klass.cancelled_transaction
  end
end

class TransitionsInParallelTest < Test::Unit::TestCase
  def setup
    @klass = Class.new do
      attr_reader :actions
      attr_reader :persisted
      
      def initialize
        @state = 'parked'
        @status = 'first_gear'
        @actions = []
        @persisted = []
        super
      end
      
      def state=(value)
        @persisted << value
        @state = value
      end
      
      def status=(value)
        @persisted << value
        @status = value
      end
      
      def save_state
        @actions << :save_state
      end
      
      def save_status
        @actions << :save_status
      end
    end
    
    @before_callbacks = []
    @after_callbacks = []
    
    @state = StateMachine::Machine.new(@klass, :state, :action => :save_state)
    @state.event :ignite
    @state.state :parked, :idling
    @state.before_transition lambda {@before_callbacks << :state}
    @state.after_transition lambda {@after_callbacks << :state}
    
    @status = StateMachine::Machine.new(@klass, :status, :action => :save_status)
    @status.event :shift_up
    @status.state :first_gear, :second_gear
    @status.before_transition lambda {@before_callbacks << :status}
    @status.after_transition lambda {@after_callbacks << :status}
    
    @object = @klass.new
    @state_transition = StateMachine::Transition.new(@object, @state, :ignite, :parked, :idling)
    @status_transition = StateMachine::Transition.new(@object, @status, :shift_up, :first_gear, :second_gear)
  end
  
  def test_should_raise_exception_if_attempted_on_the_same_state_machine
    exception = assert_raise(ArgumentError) { StateMachine::Transition.perform([@state_transition, @state_transition]) }
    assert_equal 'Cannot perform multiple transitions in parallel for the same state machine / attribute', exception.message
  end
  
  def test_should_perform
    assert_equal true, perform
  end
  
  def test_should_run_before_callbacks_in_order
    perform
    assert_equal [:state, :status], @before_callbacks
  end
  
  def test_should_persist_in_order
    perform
    assert_equal ['idling', 'second_gear'], @object.persisted
  end
  
  def test_should_run_actions_in_order
    perform
    assert_equal [:save_state, :save_status], @object.actions
  end
  
  def test_should_run_after_callbacks_in_order
    perform
    assert_equal [:state, :status], @after_callbacks
  end
  
  def test_should_halt_if_before_callback_halted_for_first_transition
    @state.before_transition lambda {throw :halt}
    
    assert_equal false, perform
    assert_equal [:state], @before_callbacks
    assert_equal [], @object.persisted
    assert_equal [], @object.actions
    assert_equal [], @after_callbacks
  end
  
  def test_should_halt_if_before_callback_halted_for_second_transition
    @status.before_transition lambda {throw :halt}
    
    assert_equal false, perform
    assert_equal [:state, :status], @before_callbacks
    assert_equal [], @object.persisted
    assert_equal [], @object.actions
    assert_equal [], @after_callbacks
  end
  
  def test_should_halt_if_action_halted_for_first_transition
    @klass.class_eval do
      def save_state
        @actions << :save_state
        throw :halt
      end
    end
    
    assert_equal false, perform
    assert_equal [:state, :status], @before_callbacks
    assert_equal ['idling', 'second_gear'], @object.persisted
    assert_equal [:save_state], @object.actions
    assert_equal [], @after_callbacks
  end
  
  def test_should_halt_if_action_halted_for_second_transition
    @klass.class_eval do
      def save_status
        @actions << :save_status
        throw :halt
      end
    end
    
    assert_equal false, perform
    assert_equal [:state, :status], @before_callbacks
    assert_equal ['idling', 'second_gear'], @object.persisted
    assert_equal [:save_state, :save_status], @object.actions
    assert_equal [], @after_callbacks
  end
  
  def test_should_not_perform_if_action_fails_for_first_transition
    @klass.class_eval do
      def save_state
        false
      end
    end
    
    assert_equal false, perform
  end
  
  def test_should_not_perform_if_action_fails_for_second_transition
    @klass.class_eval do
      def save_status
        false
      end
    end
    
    assert_equal false, perform
  end
  
  def test_should_perform_if_after_callback_halted_for_first_transition
    @state.after_transition lambda {throw :halt}
    @state.after_transition lambda {@after_callbacks << :invalid}
    
    assert_equal true, perform
    assert_equal [:state, :status], @before_callbacks
    assert_equal ['idling', 'second_gear'], @object.persisted
    assert_equal [:save_state, :save_status], @object.actions
    assert_equal [:state, :status], @after_callbacks
  end
  
  def test_should_perform_if_after_callback_halted_for_second_transition
    @status.after_transition lambda {throw :halt}
    @status.after_transition lambda {@after_callbacks << :invalid}
    
    assert_equal true, perform
    assert_equal [:state, :status], @before_callbacks
    assert_equal ['idling', 'second_gear'], @object.persisted
    assert_equal [:save_state, :save_status], @object.actions
    assert_equal [:state, :status], @after_callbacks
  end
  
  private
    def perform
      StateMachine::Transition.perform([@state_transition, @status_transition])
    end
end
