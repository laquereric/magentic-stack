# FRONT role: the browser-facing slice. It holds NO database.
#
# This controller used to carry the notes page (#notes) and its write (#create),
# both of which spoke CPCP to BACK through a private `cpcp` helper. That page was
# the pre-ADR-0072 stopgap UI; the delivery surface is the Bun FRONT, which maps
# POST /notes and GET /notes/list onto the same BACK methods in front/hooks.js.
# With the page removed, the helper had no remaining caller, so it went with it
# rather than staying as an unreachable second CPCP client -- GovernanceController
# still reaches BACK, via BackCpcpClient, which is the one FRONT client left.
#
# What remains is the host page itself: pair / bind, then enter an application.
class HomeController < ApplicationController
  def index
    @back = back_url
  end

  private

  def back_url
    Rails.application.config.x.back_url
  end
end
