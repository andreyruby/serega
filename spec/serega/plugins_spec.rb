# frozen_string_literal: true

RSpec.describe Serega::SeregaPlugins do
  let(:described_module) { described_class }

  describe ".register_plugin" do
    it "adds plugin to the @plugins list" do
      plugin = Module.new
      plugin_name = :new_plugin
      described_module.register_plugin(plugin_name, plugin)
      registered_plugin = described_module.instance_variable_get(:@plugins).fetch(plugin_name)

      expect(registered_plugin).to eq plugin
    end
  end

  describe ".find_plugin" do
    it "returns module if module provided" do
      plugin = Module.new
      expect(described_module.find_plugin(plugin)).to eq plugin
    end

    it "returns already registered plugin found by name" do
      plugin = Module.new
      plugin_name = :new_plugin
      described_module.register_plugin(plugin_name, plugin)

      expect(described_module.find_plugin(plugin_name)).to eq plugin
    end

    it "returns global plugins found by name" do
      expect(described_module.find_plugin(:root).name).to eq "#{described_module}::Root"
      expect(described_module.find_plugin(:metadata).name).to eq "#{described_module}::Metadata"
    end

    it "raises specific error if plugin not found" do
      expect { described_module.find_plugin(:foo) }
        .to raise_error Serega::SeregaError, "Plugin 'foo' does not exist"
    end

    it "raises specific error if plugin was found by name but was not registered" do
      plugin_name = "test_foo"

      # Add plugin folder and file in plugins directory
      plugin_dir = File.join(__dir__, "../../lib/serega/plugins", plugin_name)
      plugin_path = File.join(plugin_dir, "#{plugin_name}.rb")
      Dir.mkdir(plugin_dir)
      File.new(plugin_path, File::CREAT)

      expect { described_module.find_plugin(plugin_name) }
        .to raise_error Serega::SeregaError, "Plugin '#{plugin_name}' did not register itself correctly"
    ensure
      File.unlink(plugin_path)
      Dir.unlink(plugin_dir)
    end
  end

  describe ".plugin" do
    let(:serializer_class) { Class.new(Serega) }

    let(:plugin) { Module.new }

    it "runs plugin callbacks" do
      opts = {foo: :bar}
      allow(plugin).to receive_messages(
        before_load_plugin: nil,
        load_plugin: nil,
        after_load_plugin: nil
      )
      serializer_class.plugin(plugin, **opts)

      expect(plugin).to have_received(:before_load_plugin).with(serializer_class, opts)
      expect(plugin).to have_received(:load_plugin).with(serializer_class, opts)
      expect(plugin).to have_received(:after_load_plugin).with(serializer_class, opts)
    end

    it "loads not registered plugins modules" do
      serializer_class.plugin plugin
      expect(serializer_class.config.plugins).to eq [plugin]
    end

    it "loads registered plugins using plugin_name" do
      plugin.instance_exec do
        def self.plugin_name
          :test
        end
      end

      described_class.register_plugin(plugin.plugin_name, plugin)

      serializer_class.plugin(:test)
      expect(serializer_class.config.plugins).to eq [:test]
    end

    it "raises error if plugin is already loaded" do
      serializer_class.plugin(plugin)
      expect { serializer_class.plugin(plugin) }.to raise_error Serega::SeregaError, "This plugin is already loaded"
    end
  end

  describe ".plugin_used?" do
    let(:serializer_class) { Class.new(Serega) }

    it "tells if plugin has been already loaded" do
      plugin = Module.new
      expect(serializer_class.plugin_used?(plugin)).to be false
      serializer_class.plugin(plugin)
      expect(serializer_class.plugin_used?(plugin)).to be true
    end

    it "tells if plugin has been already loaded when plugin has name" do
      plugin = Module.new do
        def self.plugin_name
          :test
        end
      end
      expect(serializer_class.plugin_used?(plugin)).to be false
      serializer_class.plugin(plugin)
      expect(serializer_class.plugin_used?(plugin)).to be true
    end

    it "tells if plugin has been already loaded when given plugin name" do
      plugin = Module.new do
        def self.plugin_name
          :test
        end
      end

      described_class.register_plugin(plugin.plugin_name, plugin)

      expect(serializer_class.plugin_used?(:test)).to be false
      serializer_class.plugin(:test)
      expect(serializer_class.plugin_used?(:test)).to be true
    end
  end
end
