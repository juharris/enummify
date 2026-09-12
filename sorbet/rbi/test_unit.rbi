# typed: strict
# frozen_string_literal: true

module Test
  module Unit
    # test-unit does not ship signatures for the assertions used by this suite.
    module Assertions
      #: (Object, Object, ?String?) -> void
      def assert_equal(expected, actual, message = nil); end

      #: (Object, Object, ?String?) -> void
      def assert_include(collection, object, message = nil); end

      #: (Object, ?String?) -> void
      def assert_nil(object, message = nil); end

      #: (Object, Object, ?String?) -> void
      def assert_not_equal(expected, actual, message = nil); end

      #: (Regexp | String, String, ?String?) -> void
      def assert_not_match(pattern, string, message = nil); end

      #: (Object, Object, ?String?) -> void
      def assert_not_same(expected, actual, message = nil); end

      #: (Object, Symbol | String, ?String?) -> void
      def assert_predicate(object, predicate, message = nil); end

      #: (singleton(Exception)) { () -> void } -> Exception
      def assert_raise_kind_of(exception, &block); end

      #: (singleton(Exception)) { () -> void } -> Exception
      def assert_raises(exception, &block); end

      #: (Object, Object, ?String?) -> void
      def assert_same(expected, actual, message = nil); end
    end

    class TestCase
      include Assertions
    end
  end
end
