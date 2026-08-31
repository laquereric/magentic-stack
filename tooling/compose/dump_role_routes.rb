# frozen_string_literal: true
# Loaded via `rails runner`. Prints the application route table as JSON.
# Engine internals stay inside a mount; we record the mount, not every child.
# Do not skip by path prefix. A path starting /rails is still a drawn route
# (gap 51: GET /rails/backdoor was skipped and the gate exited 0).
require "json"

role = Rails.application.config.x.role.to_s
drawn = []
Rails.application.routes.routes.each do |r|
  path = r.path.spec.to_s.sub("(.:format)", "")
  verb = r.verb.to_s
  name = r.name.to_s
  drawn << { "verb" => verb, "path" => path, "name" => name }
end
$stdout.write(JSON.generate({ "role" => role, "routes" => drawn }))
$stdout.write("\n")
