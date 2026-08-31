# frozen_string_literal: true
# Loaded via `rails runner`. Prints the application route table as JSON.
# Engine internals stay inside a mount; we record the mount, not every child.
require "json"

role = Rails.application.config.x.role.to_s
drawn = []
skipped = []
Rails.application.routes.routes.each do |r|
  path = r.path.spec.to_s.sub("(.:format)", "")
  verb = r.verb.to_s
  name = r.name.to_s
  if path.start_with?("/rails")
    skipped << { "verb" => verb, "path" => path, "reason" => "rails internal" }
    next
  end
  drawn << { "verb" => verb, "path" => path, "name" => name }
end
$stdout.write(JSON.generate({ "role" => role, "routes" => drawn, "skipped" => skipped }))
$stdout.write("\n")
