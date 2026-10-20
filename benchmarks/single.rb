# frozen_string_literal: true

# One post with five attributes.

require_relative "support"

# One serializer per gem. A serega serializer serializes many times, thus it
# is prepared once. The others are classes: alba, panko_serializer and
# active_model_serializers make a new instance per object, blueprinter and
# oj_serializers serialize with class methods.
serega_serializer = SeregaPostSerializer.new
alba_serializer = AlbaPostResource
blueprinter_serializer = PostBlueprint
panko_serializer = PankoPostSerializer # its instances are single-use
ams_serializer = AmsPostSerializer
oj_serializer = OjPostSerializer

benchmark(
  "single", :json,
  "plain ruby" => -> { JSON.generate(PlainRuby.post(POST)) },
  "serega" => -> { JSON.generate(serega_serializer.to_h(POST, many: false)) },
  "alba" => -> { alba_serializer.new(POST).serialize },
  "blueprinter" => -> { blueprinter_serializer.render(POST) },
  "panko_serializer" => -> { panko_serializer.new.serialize_to_json(POST) },
  "active_model_serializers" => -> { ActiveModelSerializers::SerializableResource.new(POST, serializer: ams_serializer).to_json },
  "oj_serializers" => -> { oj_serializer.one_as_json(POST).to_json }
)

benchmark(
  "single", :hash,
  "plain ruby" => -> { PlainRuby.post(POST) },
  "serega" => -> { serega_serializer.to_h(POST, many: false) },
  "alba" => -> { alba_serializer.new(POST).serializable_hash },
  "blueprinter" => -> { blueprinter_serializer.render_as_hash(POST) },
  "panko_serializer" => -> { panko_serializer.new.serialize(POST) },
  "active_model_serializers" => -> { ActiveModelSerializers::SerializableResource.new(POST, serializer: ams_serializer).serializable_hash },
  "oj_serializers" => -> { oj_serializer.one_as_hash(POST) }
)
