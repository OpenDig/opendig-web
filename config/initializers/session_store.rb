# Projects are served from per-project subdomains (balua.opendig.org,
# umayri.opendig.org; balua.lvh.me in development). Sharing the session cookie
# across the registrable domain lets a single login span every project subdomain.
#
# `domain: :all` with `tld_length: 2` scopes the cookie to the top two labels of
# the request host -- "opendig.org" in production and "lvh.me" in development --
# which are both two-label registrable domains. (This cookie tld_length is
# independent of config.action_dispatch.tld_length, used for subdomain parsing.)
# `expire_after` keeps people signed in across browser restarts (without it the
# cookie is session-only and dies when the browser closes). It's a sliding window
# refreshed on each request, so an active user effectively stays logged in until
# they explicitly sign out; only ~a year of total inactivity ends the session.
# There is no inactivity timeout -- this is a field tool, not a bank.
Rails.application.config.session_store :cookie_store,
                                       key: '_opendig_session',
                                       domain: :all,
                                       tld_length: 2,
                                       expire_after: 1.year
