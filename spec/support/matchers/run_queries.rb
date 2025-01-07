# frozen_string_literal: true

RSpec::Matchers.define :run_queries do |counter|
  supports_block_expectations
  failure_message { @message }

  def callback(sqls)
    lambda do |_name, _start, _finish, _message_id, payload|
      sqls << payload[:sql]
    end
  end

  match do |actual|
    sqls = []
    ActiveSupport::Notifications.subscribed(callback(sqls), "sql.active_record") { actual.call }

    expect(sqls.size).to eq counter
  rescue RSpec::Expectations::ExpectationNotMetError => error
    # :nocov:
    @message = <<~MESSAGE.strip
      Expected to run #{counter} queries, but #{sqls.size} were actually run:
      #{sqls.map.with_index(1) { |sql, index| "    #{index}. #{sql}" }.join("\n")}
    MESSAGE

    raise error
    # :nocov:
  end
end
