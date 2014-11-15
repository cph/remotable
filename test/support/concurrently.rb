require "active_support/concern"
require "active_support/test_case"

module Idioms
  module Test
    module Concurrently
      extend ActiveSupport::Concern
      
      included do
        setup do
          @_concurrency_teardown = nil
        end

        teardown do
          cleanup_concurrency
        end
      end

      def afterwards(&block)
        @_concurrency_teardown = block
      end

      def concurrently(threads: 2)
        threads.times.map do
          Thread.new do
            begin
              yield
            ensure
              #
              # When Rails checks a connection out of the connection
              # pool, it is checked out on behalf of your current
              # thread. So for each concurrent execution of the block
              # of code under test, we'll be dragging a new connection
              # out of the connection pool. It's up to us to turn it in.
              #
              ActiveRecord::Base.connection.close
            end
          end
        end.each(&:join)
      end

      # Database work done on separate threads is not done
      # inside of the transaction that wraps each test and
      # gets rolled back.
      #
      # As a result, we need to clean up our changes to the
      # database manually _outside of the test's transaction_.
      #
      # The way to run our cleanup code outside of the
      # transaction is to perform it on a separate thread.
      #
      def cleanup_concurrency
        return unless @_concurrency_teardown
        concurrently(threads: 1, &@_concurrency_teardown)
      end
      
    end
  end
end


ActiveSupport::TestCase.send :include, Idioms::Test::Concurrently
