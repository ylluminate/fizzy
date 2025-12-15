# Respect X-Forwarded-Host/Proto headers when behind a reverse proxy (NPM, etc.)

module ReverseProxyUrlOptions
  def default_url_options
    options = super rescue {}

    forwarded_host = request.headers["X-Forwarded-Host"].presence
    forwarded_proto = request.headers["X-Forwarded-Proto"].presence

    Rails.logger.info "ReverseProxyUrlOptions: host=#{forwarded_host.inspect} proto=#{forwarded_proto.inspect}"

    options[:host] = forwarded_host if forwarded_host
    options[:protocol] = forwarded_proto if forwarded_proto

    options
  end
end

Rails.application.config.to_prepare do
  ApplicationController.prepend(ReverseProxyUrlOptions)
end
