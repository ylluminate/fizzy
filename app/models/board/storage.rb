module Board::Storage
  extend ActiveSupport::Concern
  include Storage::Totaled

  # Board's own embeds (public_description) count toward itself
  def board_for_storage_tracking
    self
  end

  private
    def calculate_real_storage_bytes
      ActiveRecord::Base.with_reading_role do
        card_image_bytes + card_embed_bytes + comment_embed_bytes + board_embed_bytes
      end
    end

    def card_image_bytes
      ActiveStorage::Attachment
        .where(record_type: "Card", record_id: cards.select(:id), name: "image")
        .joins(:blob)
        .sum("active_storage_blobs.byte_size")
    end

    def card_embed_bytes
      ActionText::RichText
        .where(record_type: "Card", record_id: cards.select(:id))
        .joins(embeds_attachments: :blob)
        .sum("active_storage_blobs.byte_size")
    end

    def comment_embed_bytes
      comment_ids = Comment.where(card_id: cards.select(:id)).select(:id)

      ActionText::RichText
        .where(record_type: "Comment", record_id: comment_ids)
        .joins(embeds_attachments: :blob)
        .sum("active_storage_blobs.byte_size")
    end

    def board_embed_bytes
      ActionText::RichText
        .where(record_type: "Board", record_id: id)
        .joins(embeds_attachments: :blob)
        .sum("active_storage_blobs.byte_size")
    end
end
