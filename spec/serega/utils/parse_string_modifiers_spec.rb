# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::ParseStringModifiers do
  def parse(str)
    described_class.parse(str)
  end

  describe ".parse" do
    it "returns empty hash when empty string provided" do
      expect(parse("")).to eq({})
    end

    it "parses single field" do
      expect(parse("id")).to eq(id: {})
    end

    it "parses multiple fields" do
      expect(parse("id, name")).to eq(id: {}, name: {})
    end

    it "parses single resource with single field" do
      expect(parse("users(id)")).to eq(users: {id: {}})
    end

    it "parses fields started with open PAREN" do
      expect(parse("(users(id))")).to eq(users: {id: {}})
    end

    it "parses fields started with extra close PAREN" do
      expect(parse(")users)")).to eq(users: {})
    end

    it "parses single resource with multiple fields" do
      expect(parse("users(id,name)")).to eq(users: {id: {}, name: {}})
    end

    it "parses multiple resources with fields" do
      fields = "id,posts(title,text),news(title,text)"
      resp = {
        id: {},
        posts: {title: {}, text: {}},
        news: {title: {}, text: {}}
      }

      expect(parse(fields)).to eq(resp)
    end

    it "parses included resources" do
      fields = "id,posts(title,text,comments(author(name),comment))"
      resp = {
        id: {},
        posts: {
          title: {},
          text: {},
          comments: {
            author: {
              name: {}
            },
            comment: {}
          }
        }
      }

      expect(parse(fields)).to eq(resp)
    end
  end
end
