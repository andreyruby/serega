# frozen_string_literal: true

# This is a helper to check we run expected SQL queries count in examples
# to prove preloads, or batch loaders work as expected

def expected_queries_count(count)
  sqls = Storage.sqls
  sqls.clear

  yield

  if sqls.count != count
    raise ExpectedQueriesCountError, <<~ERR.strip
      Expected #{count}, but there were #{sqls.count} SQL requests:
      #{sqls_to_string(sqls)}
    ERR
  else
    puts <<~MESS
      SQL requests made:
      #{sqls_to_string(sqls)}
    MESS
  end
end

def sqls_to_string(sqls)
  sqls.map.with_index(1) { |sql, index| "#{index}. #{sql}" }.join("\n")
end

class ExpectedQueriesCountError < StandardError
end

class Storage
  @sqls = []

  class << self
    attr_accessor :sqls
  end
end

ActiveSupport::Notifications.subscribe "sql.active_record" do |_name, _started, _finished, _id, payload|
  Storage.sqls << payload[:sql]
end
