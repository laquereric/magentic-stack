# frozen_string_literal: true
module Vv
  module DockerSwap
    # Disk arithmetic over shared layers -- and the trap the doc warns about.
    #
    # `docker system df -v` reports SHARED SIZE and UNIQUE SIZE per image, and
    # Docker's displayed SIZE is their sum. So adding up the displayed size of
    # every image DOUBLE-COUNTS every byte that is shared. On a host running ten
    # thin children off one common parent, the naive sum can be several times
    # the real disk cost -- which is exactly the situation this gem exists to
    # create, so the measurement has to be right or the win looks like a loss.
    #
    # The honest unit is the LAYER, which is what
    #   docker image inspect --format '{{json .RootFS.Layers}}'
    # gives you. Bytes are counted once per distinct layer id, no matter how
    # many images reference it.
    module Accounting
      module_function

      # layers: { layer_id => bytes }
      Image = Struct.new(:name, :layers, keyword_init: true)

      # Real disk: the union of all layers, each counted exactly once.
      def total_disk(images)
        u = union(images)
        return u unless u[:ok]

        { ok: true, bytes: u[:layers].values.sum, layer_count: u[:layers].size }
      end

      # The WRONG number: summing each image's displayed size. Provided so a
      # caller can show the gap rather than quietly compute it.
      def naive_sum(images)
        u = union(images)
        return u unless u[:ok]

        { ok: true, bytes: Array(images).sum { |i| (i.layers || {}).values.sum } }
      end

      # How badly the naive sum overstates the truth.
      def overcount(images)
        real  = total_disk(images)
        return real unless real[:ok]
        naive = naive_sum(images)
        return naive unless naive[:ok]

        bytes = naive[:bytes] - real[:bytes]
        { ok: true, bytes: bytes, real: real[:bytes], naive: naive[:bytes],
          ratio: (real[:bytes].zero? ? nil : (naive[:bytes].to_f / real[:bytes]).round(2)) }
      end

      # Bytes in layers referenced by MORE THAN ONE image -- the swap payoff.
      def shared_bytes(images)
        u = union(images)
        return u unless u[:ok]

        counts = reference_counts(images)
        { ok: true, bytes: u[:layers].sum { |id, sz| counts[id] > 1 ? sz : 0 } }
      end

      # Bytes only this image carries: layers no other image references.
      def unique_bytes(image, images)
        u = union(images)
        return u unless u[:ok]
        unless Array(images).any? { |i| i.name == image.name }
          return { ok: false, reason: :image_not_in_set,
                   because: "#{image.name} is not a member of the supplied image set" }
        end

        counts = reference_counts(images)
        { ok: true, bytes: (image.layers || {}).sum { |id, sz| counts[id] == 1 ? sz : 0 } }
      end

      # A layer id carrying two different byte counts means the inputs are
      # inconsistent -- refuse rather than silently pick one.
      def union(images)
        list = Array(images)
        return { ok: false, reason: :no_images, because: "expected at least one image" } if list.empty?

        acc = {}
        list.each do |img|
          (img.layers || {}).each do |id, bytes|
            if acc.key?(id) && acc[id] != bytes
              return { ok: false, reason: :inconsistent_layer_size,
                       because: "layer #{id} reported as #{acc[id]} and #{bytes} bytes; " \
                                "a layer id is content-addressed and cannot have two sizes" }
            end
            acc[id] = bytes
          end
        end
        { ok: true, layers: acc }
      end

      def reference_counts(images)
        Array(images).each_with_object(Hash.new(0)) do |img, h|
          (img.layers || {}).each_key { |id| h[id] += 1 }
        end
      end
      private_class_method :reference_counts

      RULE = "Count bytes once per distinct layer id. Never sum the displayed SIZE of several " \
             "images: Docker's SIZE is SHARED + UNIQUE, so summing double-counts exactly the " \
             "layers the shared-parent design is meant to store once."
    end
  end
end
