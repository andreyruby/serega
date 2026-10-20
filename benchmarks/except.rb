# frozen_string_literal: true

# 100 posts with relations, without the post body and the comment creation
# times. Only serega and panko_serializer have runtime `except`.

require_relative "support"

plain_ruby = lambda do |post|
  comments = post.comments.map { |comment| {id: comment.id, body: comment.body} }
  author = PlainRuby.user(post.author)
  {id: post.id, title: post.title, author_id: post.author_id, created_at: post.created_at.iso8601(3), author:, comments:}
end

# One serializer per gem. serega serializers and panko_serializer array
# serializers serialize many times, thus they are prepared once with the
# field selection.
serega_serializer = SeregaPostWithRelationsSerializer.new(except: [:body, {comments: :created_at}])
panko_serializer = Panko::ArraySerializer.new([], each_serializer: PankoPostWithRelationsSerializer, except: {instance: [:body], comments: [:created_at]})

benchmark(
  "except", :json,
  "plain ruby" => -> { JSON.generate(POSTS.map(&plain_ruby)) },
  "serega" => -> { JSON.generate(serega_serializer.to_h(POSTS)) },
  "panko_serializer" => -> { panko_serializer.serialize_to_json(POSTS) }
)

benchmark(
  "except", :hash,
  "plain ruby" => -> { POSTS.map(&plain_ruby) },
  "serega" => -> { serega_serializer.to_h(POSTS) },
  "panko_serializer" => -> { panko_serializer.serialize(POSTS) }
)
