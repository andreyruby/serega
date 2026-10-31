# frozen_string_literal: true

RSpec.describe Serega::SeregaPlan::Selection do
  subject(:names) { selected_names(selection) }

  let(:selection) { described_class.new(a, modifiers) }
  let(:modifiers) { {} }
  let(:base_class) { Class.new(Serega) }

  let(:a) do
    serializer = Class.new(base_class)

    serializer.attribute :a1
    serializer.attribute :a2
    serializer.attribute :a3, hide: true

    serializer.attribute :b, serializer: b, hide: true
    serializer.attribute :c, serializer: c, hide: true
    serializer.attribute :d, serializer: d
    serializer
  end

  let(:b) do
    serializer = Class.new(base_class)
    serializer.attribute :b1
    serializer.attribute :b2
    serializer.attribute :b3, hide: true
    serializer
  end

  let(:c) do
    serializer = Class.new(base_class)
    serializer.attribute :c1
    serializer.attribute :c2
    serializer.attribute :c3, hide: true
    serializer
  end

  let(:d) do
    serializer = Class.new(base_class)
    serializer.attribute :d1
    serializer.attribute :d2
    serializer.attribute :d3, hide: true
    serializer
  end

  # Names of the selected attributes, with the names of the child selection
  # of each relation
  def selected_names(selection)
    selection.attributes.to_h do |attribute|
      child = selection.child(attribute)
      [attribute.name, child && selected_names(child)]
    end
  end

  describe "#attributes" do
    context "without modifiers" do
      let(:modifiers) { {} }

      it "selects the not hidden attributes" do
        expect(names).to eq(a1: nil, a2: nil, d: {d1: nil, d2: nil})
      end
    end

    context "with :only" do
      let(:modifiers) { {only: {a2: {}, d: {d1: {}}}, except: {}, with: {}} }

      it "selects the named attributes" do
        expect(names).to eq(a2: nil, d: {d1: nil})
      end
    end

    context "when :only names a hidden attribute" do
      let(:modifiers) { {only: {a3: {}}, except: {}, with: {}} }

      it "selects the named attribute" do
        expect(names).to eq(a3: nil)
      end
    end

    context "when :only limits the level and :with names a hidden attribute" do
      let(:modifiers) { {only: {a1: {}}, except: {}, with: {a3: {}}} }

      it "selects the attributes that :only and :with name" do
        expect(names).to eq(a1: nil, a3: nil)
      end
    end

    context "when :except names the attribute that :only and :with name" do
      let(:modifiers) { {only: {a1: {}}, except: {a1: {}}, with: {a1: {}}} }

      it "selects no attributes" do
        expect(names).to eq({})
      end
    end

    context "with :except" do
      let(:modifiers) { {only: {}, except: {a2: {}, d: {d1: {}}}, with: {}} }

      it "selects the not hidden attributes without the named attributes" do
        expect(names).to eq(a1: nil, d: {d2: nil})
      end
    end

    context "with :with" do
      let(:modifiers) { {only: {}, except: {}, with: {a3: {}, b: {}, c: {c3: {}}}} }

      it "selects the not hidden attributes and the named attributes" do
        expect(names).to eq(
          a1: nil,
          a2: nil,
          a3: nil,
          b: {b1: nil, b2: nil},
          c: {c1: nil, c2: nil, c3: nil},
          d: {d1: nil, d2: nil}
        )
      end
    end

    context "when :only names nested fields only" do
      let(:modifiers) { {only: {d: {d1: {}}}, except: except, with: with} }
      let(:except) { {} }
      let(:with) { {} }

      it "selects the named relation only" do
        expect(names).to eq(d: {d1: nil})
      end

      context "when :except hides an attribute of the level" do
        let(:except) { {a2: {}} }

        it "selects the other not hidden attributes and the named relation" do
          expect(names).to eq(a1: nil, d: {d1: nil})
        end
      end

      context "when :except hides nested fields only" do
        let(:except) { {d: {d2: {}}} }

        it "selects the named relation only" do
          expect(names).to eq(d: {d1: nil})
        end
      end

      context "when :with adds an attribute of the level" do
        let(:with) { {a3: {}} }

        it "selects the not hidden attributes, the added attribute and the named relation" do
          expect(names).to eq(a1: nil, a2: nil, a3: nil, d: {d1: nil})
        end
      end
    end
  end

  describe "#child" do
    subject(:child) { selection.child(attribute) }

    let(:attribute) { a.attributes[:d] }

    it "returns the selection of the relation serializer" do
      expect(child.serializer_class).to be d
    end

    context "with an attribute without a relation" do
      let(:attribute) { a.attributes[:a1] }

      it "returns nil" do
        expect(child).to be_nil
      end
    end
  end

  describe "#builder_class" do
    it "returns SeregaResultBuilder" do
      expect(selection.builder_class).to be Serega::SeregaResultBuilder
    end
  end

  describe "#preloads" do
    subject(:preloads) { selection.preloads(attribute) }

    let(:attribute) { Class.new(base_class) { attribute :posts, preload: :posts, value: proc { [] } }.attributes[:posts] }

    it "returns the preloads of the attribute" do
      expect(preloads).to eq :posts
    end
  end
end
