# frozen_string_literal: true

RSpec.describe Serega do
  let(:user) { Struct.new(:name).new("Ann") }

  def in_threads(count)
    gate = Queue.new
    threads = Array.new(count) do
      Thread.new do
        gate.pop
        yield
      end
    end

    count.times { gate << true }
    threads.map(&:value)
  end

  context "when threads serialize with new serializers at once" do
    let(:user_serializers) do
      Array.new(20) do
        Class.new(described_class) do
          plugin :root
          attribute :name
        end
      end
    end

    it "serializes in every thread" do
      results = user_serializers.flat_map { |serializer| in_threads(8) { serializer.to_h(user) } }

      expect(results).to all eq(data: {name: "Ann"})
    end
  end

  context "when a thread serializes while another thread locks the serializer" do
    let!(:user_serializer) { Class.new(described_class) { attribute :name } }
    let(:locking) { Queue.new }
    let(:release) { Queue.new }

    before do
      allow(user_serializer.config).to receive(:opts).and_wrap_original do |original|
        locking << true
        release.pop
        original.call
      end
    end

    it "locks the serializer once" do
      first = Thread.new { user_serializer.to_h(user) }
      locking.pop
      second = Thread.new { user_serializer.to_h(user) }
      # Other code, such as the debug gem, can put a new thread to sleep before it reaches the mutex
      Thread.pass until second.status == "sleep" && second.backtrace_locations.any? { |location| location.base_label == "lock" }
      2.times { release << true }

      expect([first.value, second.value]).to all eq(name: "Ann")
      expect(user_serializer.config).to have_received(:opts).once
    end
  end
end
