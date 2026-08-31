# frozen_string_literal: true

# ROLE=vault fails closed at boot when caller tokens / master key / store path
# are missing, and when SECRET_KEY_BASE is the pod default. Other roles skip.
Rails.application.config.after_initialize do
  Vault::Boot.abort_if_vault!(Rails.application.config.x.role)
end
