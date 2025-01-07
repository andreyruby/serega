# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::MethodSignature do
  it "generates signatures for procs" do
    callable = proc {}
    expect(described_class.call(callable, pos_limit: 0)).to eq "0"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 0, keyword_args: [:ctx])).to eq "0_ctx"
    expect(described_class.call(callable, pos_limit: 1, keyword_args: [:ctx])).to eq "1_ctx"
    expect(described_class.call(callable, pos_limit: 2, keyword_args: [:ctx])).to eq "2_ctx"

    callable = proc { |one| }
    expect(described_class.call(callable, pos_limit: 0)).to eq "0"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "1"
    expect(described_class.call(callable, pos_limit: 3, keyword_args: [:ctx])).to eq "1"

    callable = proc { |*one| }
    expect(described_class.call(callable, pos_limit: 0)).to eq "0"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 3, keyword_args: [:ctx])).to eq "3"

    callable = proc { |one, two = 2| }
    expect(described_class.call(callable, pos_limit: 0)).to eq "0"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 3, keyword_args: [:ctx])).to eq "2"

    callable = proc { |one, *two| }
    expect(described_class.call(callable, pos_limit: 0)).to eq "0"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 3)).to eq "3"
    expect(described_class.call(callable, pos_limit: 3, keyword_args: [:ctx])).to eq "3"

    callable = proc { |one, two = 2, *three| }
    expect(described_class.call(callable, pos_limit: 0)).to eq "0"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 3)).to eq "3"
    expect(described_class.call(callable, pos_limit: 4)).to eq "4"
    expect(described_class.call(callable, pos_limit: 4, keyword_args: [:ctx])).to eq "4"

    callable = proc { |one:, two: 2, **three, &block| }
    expect(described_class.call(callable, pos_limit: 5, keyword_args: [:one])).to eq "0_one"
    expect(described_class.call(callable, pos_limit: 5, keyword_args: [:one, :two])).to eq "0_one_two"
    expect(described_class.call(callable, pos_limit: 5, keyword_args: [:one, :two, :a, :b])).to eq "0_a_b_one_two"
  end

  it "generates signatures for lambdas" do
    callable = lambda {}
    expect(described_class.call(callable, pos_limit: 0)).to eq "0"
    expect(described_class.call(callable, pos_limit: 1)).to eq "0"
    expect(described_class.call(callable, pos_limit: 2)).to eq "0"
    expect(described_class.call(callable, pos_limit: 0, keyword_args: [:ctx])).to eq "0"
    expect(described_class.call(callable, pos_limit: 1, keyword_args: [:ctx])).to eq "0"
    expect(described_class.call(callable, pos_limit: 2, keyword_args: [:ctx])).to eq "0"

    callable = lambda { |one| }
    expect(described_class.call(callable, pos_limit: 0)).to eq "1"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "1"
    expect(described_class.call(callable, pos_limit: 3, keyword_args: [:ctx])).to eq "1"

    callable = lambda { |*one| }
    expect(described_class.call(callable, pos_limit: 0)).to eq "0"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 3, keyword_args: [:ctx])).to eq "3"

    callable = lambda { |one, two = 2| }
    expect(described_class.call(callable, pos_limit: 0)).to eq "1"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 3, keyword_args: [:ctx])).to eq "2"

    callable = lambda { |one, *two| }
    expect(described_class.call(callable, pos_limit: 0)).to eq "1"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 3)).to eq "3"
    expect(described_class.call(callable, pos_limit: 3, keyword_args: [:ctx])).to eq "3"

    callable = lambda { |one, two = 2, *three| }
    expect(described_class.call(callable, pos_limit: 0)).to eq "1"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 3)).to eq "3"
    expect(described_class.call(callable, pos_limit: 4)).to eq "4"
    expect(described_class.call(callable, pos_limit: 4, keyword_args: [:ctx])).to eq "4"

    callable = lambda { |one:, two: 2, **three, &block| }
    expect(described_class.call(callable, pos_limit: 5, keyword_args: [:one])).to eq "0_one"
    expect(described_class.call(callable, pos_limit: 5, keyword_args: [:one, :two])).to eq "0_one_two"
    expect(described_class.call(callable, pos_limit: 5, keyword_args: [:one, :two, :a, :b])).to eq "0_a_b_one_two"
  end

  it "generates signatures for callable objects" do
    callable = Class.new do
      def self.call
      end
    end
    expect(described_class.call(callable, pos_limit: 0)).to eq "0"
    expect(described_class.call(callable, pos_limit: 1)).to eq "0"
    expect(described_class.call(callable, pos_limit: 2)).to eq "0"
    expect(described_class.call(callable, pos_limit: 0, keyword_args: [:ctx])).to eq "0"
    expect(described_class.call(callable, pos_limit: 1, keyword_args: [:ctx])).to eq "0"
    expect(described_class.call(callable, pos_limit: 2, keyword_args: [:ctx])).to eq "0"

    callable = Class.new do
      def self.call(one)
      end
    end
    expect(described_class.call(callable, pos_limit: 0)).to eq "1"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "1"
    expect(described_class.call(callable, pos_limit: 3, keyword_args: [:ctx])).to eq "1"

    callable = Class.new do
      def self.call(*one)
      end
    end
    expect(described_class.call(callable, pos_limit: 0)).to eq "0"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 3, keyword_args: [:ctx])).to eq "3"

    callable = Class.new do
      def self.call(one, two = 2)
      end
    end
    expect(described_class.call(callable, pos_limit: 0)).to eq "1"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 3, keyword_args: [:ctx])).to eq "2"

    callable = Class.new do
      def self.call(one, *two)
      end
    end
    expect(described_class.call(callable, pos_limit: 0)).to eq "1"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 3)).to eq "3"
    expect(described_class.call(callable, pos_limit: 3, keyword_args: [:ctx])).to eq "3"

    callable = Class.new do
      def self.call(one, two = 2, *three)
      end
    end
    expect(described_class.call(callable, pos_limit: 0)).to eq "1"
    expect(described_class.call(callable, pos_limit: 1)).to eq "1"
    expect(described_class.call(callable, pos_limit: 2)).to eq "2"
    expect(described_class.call(callable, pos_limit: 3)).to eq "3"
    expect(described_class.call(callable, pos_limit: 4)).to eq "4"
    expect(described_class.call(callable, pos_limit: 4, keyword_args: [:ctx])).to eq "4"

    callable = Class.new do
      def self.call(one:, two: 2, **three, &block)
      end
    end
    expect(described_class.call(callable, pos_limit: 5, keyword_args: [:one])).to eq "0_one"
    expect(described_class.call(callable, pos_limit: 5, keyword_args: [:one, :two])).to eq "0_one_two"
    expect(described_class.call(callable, pos_limit: 5, keyword_args: [:one, :two, :a, :b])).to eq "0_a_b_one_two"
  end

  it "returns 1 if provided callable with not named *rest parameters" do
    callable = :one?.to_proc
    expect(described_class.call(callable, pos_limit: 2)).to eq "1"

    callable = :one?.to_proc.method(:call)
    expect(described_class.call(callable, pos_limit: 2)).to eq "1"
  end
end
