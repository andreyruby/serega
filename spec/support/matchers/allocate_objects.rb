# frozen_string_literal: true

# Expects the block to allocate exactly these objects, by type:
#   expect { serializer.to_h(user) }.to allocate_objects(T_HASH: 1, T_ARRAY: 2)
#
# The block and the count run once before the count, thus lazily built code
# and caches are ready.
RSpec::Matchers.define :allocate_objects do |expected|
  supports_block_expectations

  # :nocov:
  failure_message { "Expected to allocate #{expected}, but allocated #{@allocated}" }
  # :nocov:

  def count_allocations
    before = {}
    after = {}
    GC.disable
    ObjectSpace.count_objects(before)
    yield
    ObjectSpace.count_objects(after)
    after.filter_map { |type, count| [type, count - before.fetch(type, 0)] if type.start_with?("T_") && count != before[type] }.to_h
  ensure
    GC.enable
  end

  match do |actual|
    count_allocations(&actual)
    @allocated = count_allocations(&actual)
    @allocated == expected
  end
end
