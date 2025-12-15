ActiveSupport.on_load(:active_storage_attachment) do
  include Storage::AttachmentTracking
end

ActiveSupport.on_load(:active_storage_blob) do
  ActiveStorage::DiskController.after_action only: :show do
    expires_in 5.minutes, public: true
  end
end

# Don't configure replica connections for ActiveStorage::Record.
# When ActiveStorage uses `connects_to`, it creates a separate connection pool
# from ApplicationRecord. This causes after_commit callbacks to fire in
# non-deterministic order - the Attachment's create_variants callback can fire
# before the User model's upload callback, causing FileNotFoundError when
# using `process: :immediately` for variants.
# See: https://github.com/rails/rails/issues/53694
ActiveSupport.on_load(:active_storage_record) do
  configure_replica_connections
end

module ActiveStorageControllerExtensions
  extend ActiveSupport::Concern

  included do
    before_action do
      # Respect X-Forwarded headers when behind reverse proxy (NPM, etc.)
      forwarded_proto = request.headers["X-Forwarded-Proto"].presence
      forwarded_host = request.headers["X-Forwarded-Host"].presence
      
      ActiveStorage::Current.url_options = {
        protocol: forwarded_proto ? "#{forwarded_proto}://" : request.protocol,
        host: forwarded_host || request.host,
        port: forwarded_host ? nil : request.port,  # Don't include port when using forwarded host
        script_name: request.script_name
      }
    end
  end
end

module ActiveStorageDirectUploadsControllerExtensions
  extend ActiveSupport::Concern

  included do
    include Authentication
    skip_forgery_protection if: :authenticate_by_bearer_token
  end
end

Rails.application.config.to_prepare do
  ActiveStorage::BaseController.include ActiveStorageControllerExtensions
  ActiveStorage::DirectUploadsController.include ActiveStorageDirectUploadsControllerExtensions
end
