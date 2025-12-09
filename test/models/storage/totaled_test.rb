require "test_helper"

class Storage::TotaledTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
    @board = boards(:writebook)
  end


  # bytes_used (fast snapshot)

  test "bytes_used returns 0 when no storage_total exists" do
    assert_nil @account.storage_total
    assert_equal 0, @account.bytes_used
  end

  test "bytes_used returns snapshot value" do
    @account.create_storage_total!(bytes_stored: 10_000)
    assert_equal 10_000, @account.bytes_used
  end

  test "bytes_used does not include pending entries (fast path)" do
    @account.create_storage_total!(bytes_stored: 1000)

    # Create pending entry (not materialized)
    Storage::Entry.record(account: @account, delta: 500, operation: "attach")

    # bytes_used is fast path - only reads snapshot
    assert_equal 1000, @account.bytes_used
  end


  # bytes_used_exact (snapshot + pending)

  test "bytes_used_exact creates storage_total if missing" do
    assert_nil @account.storage_total

    @account.bytes_used_exact

    assert_not_nil @account.reload.storage_total
  end

  test "bytes_used_exact includes pending entries" do
    # Create first entry and set cursor at that entry
    entry = Storage::Entry.record(account: @account, delta: 500, operation: "attach")
    @account.create_storage_total!(bytes_stored: 500, last_entry_id: entry.id)

    # Small delay to ensure UUIDv7 timestamp advances
    travel 1.second

    # Create pending entry AFTER cursor
    Storage::Entry.record(account: @account, delta: 256, operation: "attach")

    # 500 (snapshot) + 256 (pending) = 756
    assert_equal 756, @account.bytes_used_exact
  end

  test "bytes_used_exact returns 0 when no entries and no snapshot" do
    assert_equal 0, @account.bytes_used_exact
  end


  # materialize_storage

  test "materialize_storage creates storage_total if missing" do
    assert_nil @account.storage_total

    Storage::Entry.record(account: @account, delta: 1024, operation: "attach")
    @account.materialize_storage

    total = @account.reload.storage_total
    assert_not_nil total
    assert_equal 1024, total.bytes_stored
  end

  test "materialize_storage processes all pending entries" do
    Storage::Entry.record(account: @account, delta: 1000, operation: "attach")
    Storage::Entry.record(account: @account, delta: 2000, operation: "attach")
    Storage::Entry.record(account: @account, delta: -500, operation: "detach")

    @account.materialize_storage

    assert_equal 2500, @account.storage_total.bytes_stored
    assert_equal 0, @account.storage_total.pending_entries.count
  end

  test "materialize_storage updates cursor to latest entry" do
    entry1 = Storage::Entry.record(account: @account, delta: 1000, operation: "attach")
    entry2 = Storage::Entry.record(account: @account, delta: 500, operation: "attach")

    @account.materialize_storage

    assert_equal entry2.id, @account.storage_total.last_entry_id
  end

  test "materialize_storage is idempotent when no new entries" do
    Storage::Entry.record(account: @account, delta: 1000, operation: "attach")
    @account.materialize_storage

    initial_bytes = @account.storage_total.bytes_stored
    initial_cursor = @account.storage_total.last_entry_id

    @account.materialize_storage

    assert_equal initial_bytes, @account.storage_total.bytes_stored
    assert_equal initial_cursor, @account.storage_total.last_entry_id
  end

  test "materialize_storage processes only entries since cursor" do
    entry1 = Storage::Entry.record(account: @account, delta: 1000, operation: "attach")
    @account.materialize_storage

    assert_equal 1000, @account.storage_total.bytes_stored

    # Small delay to ensure UUIDv7 timestamp advances
    travel 1.second

    # Add more entries
    Storage::Entry.record(account: @account, delta: 500, operation: "attach")
    @account.materialize_storage

    assert_equal 1500, @account.storage_total.bytes_stored
  end

  test "materialize_storage does nothing when no entries" do
    @account.materialize_storage

    total = @account.reload.storage_total
    assert_not_nil total
    assert_equal 0, total.bytes_stored
    assert_nil total.last_entry_id
  end

  test "materialize_storage handles concurrent calls safely" do
    # Pre-create storage_total to avoid unique constraint race
    @account.create_storage_total!

    Storage::Entry.record(account: @account, delta: 1000, operation: "attach")

    # Simulate concurrent materialization
    threads = 3.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          @account.materialize_storage
        end
      end
    end
    threads.each(&:join)

    # Should still have correct total
    assert_equal 1000, @account.reload.storage_total.bytes_stored
  end


  # storage_entries association

  test "account has storage_entries association" do
    entry = Storage::Entry.record(account: @account, delta: 1024, operation: "attach")

    assert_includes @account.storage_entries, entry
  end

  test "board has storage_entries association" do
    entry = Storage::Entry.record(account: @account, board: @board, delta: 1024, operation: "attach")

    assert_includes @board.storage_entries, entry
  end


  # storage_total association

  test "storage_total is destroyed when owner is destroyed" do
    @account.create_storage_total!(bytes_stored: 1000)
    total_id = @account.storage_total.id

    # Create a new account to destroy (don't destroy fixtures)
    new_account = Account.create!(name: "Temp Account")
    new_account.create_storage_total!(bytes_stored: 500)
    storage_total_id = new_account.storage_total.id

    new_account.destroy!

    assert_not Storage::Total.exists?(storage_total_id)
  end


  # Board-specific tests

  test "board bytes_used works independently of account" do
    # Create entries for both account and board
    Storage::Entry.record(account: @account, board: nil, delta: 1000, operation: "attach")
    Storage::Entry.record(account: @account, board: @board, delta: 500, operation: "attach")

    @account.materialize_storage
    @board.materialize_storage

    # Account sees all its entries (1000 + 500 = 1500)
    assert_equal 1500, @account.bytes_used

    # Board only sees entries with its board_id (500)
    assert_equal 500, @board.bytes_used
  end

  test "board and account have independent cursors" do
    entry1 = Storage::Entry.record(account: @account, board: @board, delta: 1000, operation: "attach")

    @account.materialize_storage
    # Board not yet materialized

    entry2 = Storage::Entry.record(account: @account, board: @board, delta: 500, operation: "attach")

    # Account cursor at entry1, board has no cursor yet
    assert_equal entry1.id, @account.storage_total.last_entry_id

    @board.materialize_storage

    # Board cursor now at entry2
    assert_equal entry2.id, @board.storage_total.last_entry_id
    assert_equal 1500, @board.bytes_used
  end
end
