# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

result = Mmg::Medallion::Seed.call
if result[:ok]
  Rails.logger.info("mmg-medallion seed ok: #{result[:seeded].inspect}") if defined?(Rails)
else
  msg = "mmg-medallion seed failed: #{result[:because]}"
  if defined?(Rails)
    Rails.logger.error(msg)
  else
    warn msg
  end
end
