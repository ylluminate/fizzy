# Respect X-Forwarded-Host/Proto headers when behind a reverse proxy (NPM, etc.)
# Uses prepend to avoid modifying upstream files, reducing merge conflicts.

module ReverseProxyUrlOptions
  extend ActiveSupport::Concern

  included do
    prepend_before_action :set_reverse_proxy_url_options
  end

  def set_reverse_proxy_url_options
    forwarded_host = request.headers["X-Forwarded-Host"].presence
    forwarded_proto = request.headers["X-Forwarded-Proto"].presence

    # Set Active Storage URL options for blob/variant URL generation
    if forwarded_host || forwarded_proto
      ActiveStorage::Current.url_options = {
        protocol: forwarded_proto ? "#{forwarded_proto}://" : request.protocol,
        host: forwarded_host || request.host,
        port: forwarded_host ? nil : request.port,
        script_name: request.script_name
      }
    end
  end

  def default_url_options
    options = super rescue {}

    if (forwarded_host = request.headers["X-Forwarded-Host"].presence)
      options[:host] = forwarded_host
    end

    if (forwarded_proto = request.headers["X-Forwarded-Proto"].presence)
      options[:protocol] = forwarded_proto
    end

    options
  end
end

Rails.application.config.to_prepare do
  ApplicationController.prepend(ReverseProxyUrlOptions)
end
