module Gym
  # Normalizes target rep strings such as "5" or "8-12" into min/max bounds.
  # Ported from openGym's rep-range.js (AGPL-3.0).
  module RepRange
    SINGLE = /\A(\d+)\z/
    RANGE = /\A(\d+)\s*-\s*(\d+)\z/

    module_function

    def normalize(raw)
      text = raw.to_s.strip

      if (match = text.match(RANGE))
        lo = match[1].to_i
        hi = match[2].to_i
        lo, hi = hi, lo if hi < lo
        {min: lo, max: hi}
      elsif (match = text.match(SINGLE))
        n = match[1].to_i
        {min: n, max: n}
      end
    end

    def top(raw)
      range = normalize(raw)
      range&.fetch(:max)
    end

    def bottom(raw)
      range = normalize(raw)
      range&.fetch(:min)
    end
  end
end
