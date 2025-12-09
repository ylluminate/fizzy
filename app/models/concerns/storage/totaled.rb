module Storage::Totaled
  extend ActiveSupport::Concern

  included do
    has_one :storage_total, as: :owner, class_name: "Storage::Total", dependent: :destroy
    has_many :storage_entries, class_name: "Storage::Entry", foreign_key: foreign_key_for_storage
  end

  class_methods do
    def foreign_key_for_storage
      "#{model_name.singular}_id"
    end
  end

  # Fast: materialized snapshot (may be slightly stale)
  def bytes_used
    storage_total&.bytes_stored || 0
  end

  # Exact: snapshot + pending entries
  def bytes_used_exact
    (storage_total || create_storage_total!).current_usage
  end

  def materialize_storage_later
    Storage::MaterializeJob.perform_later(self)
  end

  # Materialize all pending entries into snapshot
  def materialize_storage
    total = storage_total || create_storage_total!

    total.with_lock do
      latest_entry_id = storage_entries.maximum(:id)

      if latest_entry_id && total.last_entry_id != latest_entry_id
        scope = storage_entries.where(id: ..latest_entry_id)
        scope = scope.where.not(id: ..total.last_entry_id) if total.last_entry_id
        delta_sum = scope.sum(:delta)

        total.update! bytes_stored: total.bytes_stored + delta_sum, last_entry_id: latest_entry_id
      end
    end
  end

  # Reconcile ledger against actual attachment storage
  def reconcile_storage
    real_bytes, ledger_bytes = calculate_real_storage_bytes, bytes_used_exact
    diff = real_bytes - ledger_bytes

    if diff.nonzero?
      Storage::Entry.record \
        account: is_a?(Account) ? self : account,
        board: is_a?(Board) ? self : nil,
        recordable: nil,
        delta: diff,
        operation: "reconcile"
    end
  end

  private
    def calculate_real_storage_bytes
      raise NotImplementedError, "Subclass must implement calculate_real_storage_bytes"
    end
end
