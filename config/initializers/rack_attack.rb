# Throttles for the account endpoints, to slow down spam signups, password
# guessing, and using the mail forms to spam other people's inboxes.
#
# Requests currently reach the app from the ingress/node addresses rather than
# the client's own IP (the DigitalOcean load balancer doesn't pass it through),
# so these throttle by email address plus a global cap, not per IP.
Rack::Attack.enabled = !Rails.env.test?

normalized_email = ->(req) { req.params['email'].to_s.strip.downcase.presence }

# Signups across the whole site. Real signups come in a trickle; a burst is a bot.
Rack::Attack.throttle('signup/global', limit: 20, period: 1.hour) do |req|
  'all' if req.post? && req.path == '/signup'
end

# Password guesses against one account.
Rack::Attack.throttle('login/email', limit: 10, period: 15.minutes) do |req|
  normalized_email.call(req) if req.post? && req.path == '/login'
end

# Reset/confirmation emails to one address (login re-sends confirmation links).
Rack::Attack.throttle('mail/email', limit: 5, period: 1.hour) do |req|
  normalized_email.call(req) if req.post? && ['/password/forgot', '/signup'].include?(req.path)
end
