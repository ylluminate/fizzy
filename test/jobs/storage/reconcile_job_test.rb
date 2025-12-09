require "test_helper"

class Storage::ReconcileJobTest < ActiveJob::TestCase
  setup do
    Current.session = sessions(:david)
    @account = accounts("37s")
    @board = boards(:writebook)
    @card = cards(:logo)
  end

  test "calls reconcile_storage on account" do
    # Create some ledger entries
    Storage::Entry.record(account: @account, delta: 1000, operation: "attach")
    @account.materialize_storage

    # Mock calculate_real_storage_bytes to return a different value
    @account.stubs(:calculate_real_storage_bytes).returns(1500)
    Storage::ReconcileJob.perform_now(@account)

    # Should have created a reconcile entry
    reconcile_entry = Storage::Entry.find_by(operation: "reconcile", account: @account)
    assert_not_nil reconcile_entry
    assert_equal 500, reconcile_entry.delta  # 1500 real - 1000 ledger
  end

  test "calls reconcile_storage on board" do
    Storage::Entry.record(account: @account, board: @board, delta: 500, operation: "attach")
    @board.materialize_storage

    @board.stubs(:calculate_real_storage_bytes).returns(800)
    Storage::ReconcileJob.perform_now(@board)

    reconcile_entry = Storage::Entry.find_by(operation: "reconcile", board: @board)
    assert_not_nil reconcile_entry
    assert_equal 300, reconcile_entry.delta  # 800 real - 500 ledger
  end

  test "no entry created when ledger matches reality" do
    Storage::Entry.record(account: @account, delta: 1000, operation: "attach")
    @account.materialize_storage

    initial_count = Storage::Entry.count

    @account.stubs(:calculate_real_storage_bytes).returns(1000)
    Storage::ReconcileJob.perform_now(@account)

    assert_equal initial_count, Storage::Entry.count
  end

  test "handles negative reconciliation (ledger over-counted)" do
    Storage::Entry.record(account: @account, delta: 2000, operation: "attach")
    @account.materialize_storage

    @account.stubs(:calculate_real_storage_bytes).returns(1500)
    Storage::ReconcileJob.perform_now(@account)

    reconcile_entry = Storage::Entry.find_by(operation: "reconcile", account: @account)
    assert_equal -500, reconcile_entry.delta  # 1500 real - 2000 ledger
  end

  test "job queued to backend queue" do
    assert_equal "backend", Storage::ReconcileJob.new.queue_name
  end
end
