# Respect X-Forwarded-Host/Proto headers when behind a reverse proxy (NPM, etc.)
# Uses prepend to avoid modifying upstream files, reducing merge conflicts.

module ReverseProxyUrlOptions
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
