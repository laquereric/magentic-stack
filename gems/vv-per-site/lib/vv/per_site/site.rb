# frozen_string_literal: true

module Vv
  module PerSite
    # A particular site in the market. The OKF tree is shared knowledge;
    # this row (and its `Cta` children) is the per-site data that aims an
    # anonymous visitor at *this* site's registered calls to action.
    class Site < Record
      self.table_name = "vv_per_site_sites"

      has_many :ctas, class_name: "Vv::PerSite::Cta", inverse_of: :site,
                      dependent: :destroy

      validates :key, :name, :bundle_key, presence: true
      validates :key, uniqueness: true

      def bundle_nodes
        OkfNode.in_bundle(bundle_key)
      end

      def guide
        Guide.new(site: self)
      end
    end
  end
end
