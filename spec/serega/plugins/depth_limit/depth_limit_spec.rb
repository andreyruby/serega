# frozen_string_literal: true

# Load plugin code
Class.new(Serega).plugin :depth_limit, limit: 10

RSpec.describe Serega::SeregaPlugins::DepthLimit do
  describe "loading" do
    let(:serializer) { Class.new(Serega) }

    it "sets limit" do
      serializer.plugin :depth_limit, limit: 3
      expect(serializer.config.depth_limit.limit).to eq 3
    end

    it "requires to add limit during plugin initialization" do
      expect { serializer.plugin :depth_limit }
        .to raise_error Serega::SeregaError,
          "Please provide :limit option. Example: `plugin :depth_limit, limit: 10`"
    end

    it "raises error if plugin defined with unknown option" do
      serializer = Class.new(Serega)
      expect { serializer.plugin(:depth_limit, foo: :bar) }
        .to raise_error Serega::SeregaError, <<~MESSAGE.strip
          Plugin :depth_limit does not accept the :foo option. Allowed options:
            - :limit [Integer] - Maximum serialization depth.
        MESSAGE
    end
  end

  describe "configuration" do
    let(:serializer) { Class.new(Serega) { plugin :depth_limit, limit: 1 } }

    it "preserves depth_limit config" do
      depth_limit1 = serializer.config.depth_limit
      depth_limit2 = serializer.config.depth_limit
      expect(depth_limit1).to be depth_limit2
    end

    it "allows to change depth_limit via #limit= methods" do
      serializer.config.depth_limit.limit = 5
      expect(serializer.config.depth_limit.limit).to eq 5
    end

    it "raises error when provided incorrect value" do
      config = serializer.config.depth_limit
      expect { config.limit = :one }.to raise_error "Depth limit must be an Integer"
      expect { config.limit = true }.to raise_error "Depth limit must be an Integer"
      expect { config.limit = nil }.to raise_error "Depth limit must be an Integer"
    end
  end

  describe "serialization" do
    let(:parent) { Class.new(Serega) { plugin :depth_limit, limit: 2 } }
    let(:posts_serializer) { Class.new(parent) }
    let(:comments_serializer) { Class.new(parent) { attribute :text } }

    before do
      posts_serializer.attribute :comments, serializer: comments_serializer
      comments_serializer.attribute :post, serializer: posts_serializer
      posts_serializer.freeze
      comments_serializer.freeze
    end

    it "raises error if depth limit was exceeded when instantiating serializer" do
      expect { posts_serializer.new }.to raise_error Serega::SeregaError, "Depth limit was exceeded"

      fields = {only: {comments: :post}} # post -> comments -> post (depth is 3)
      expect { posts_serializer.new(fields) }
        .to raise_error Serega::SeregaError, "Depth limit was exceeded"
    end

    it "raises error when depth limit was exceeded accidentally for cyclic relations (without specifying fields)" do
      # post -> comments -> post -> comments ... (depth is infinite)
      expect { posts_serializer.new }.to raise_error Serega::DepthLimitError, "Depth limit was exceeded"
    end

    it "raises error that has additional #details method" do
      expect { posts_serializer.new }.to raise_error do |err|
        expect(err.details).to eq "#{posts_serializer} (depth limit: 2) -> comments -> post"
      end
    end

    it "does not raise error if depth error was not exceeded" do
      fields = {only: {comments: :text}} # post -> comments (depth is 2)
      expect { posts_serializer.new(fields) }.not_to raise_error
    end
  end

  context "when the config is deeply frozen", if: defined?(Ractor) do
    let(:frozen_config) do
      serializer_class = Class.new(Serega) do
        plugin :depth_limit, limit: 3
      end
      Ractor.make_shareable(serializer_class.config)
    end

    it "returns the depth_limit config" do
      expect(frozen_config.depth_limit).to be_a Serega::SeregaPlugins::DepthLimit::DepthLimitConfig
    end
  end
end
