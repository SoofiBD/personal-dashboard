module Gym
  # Session effort summary. Ported from the essentials of openGym's effort.js
  # (AGPL-3.0): tonnage for reps-mode work, total time for timed sets.
  module Effort
    module_function

    # Tonnage (kg lifted) over completed working sets that carry both a load
    # and a rep count. Warmups are excluded on purpose: they are preparation,
    # not work.
    def tonnage(sets)
      sets
        .select { |set| set.done? && set.kind == "working" && set.weight.to_f.positive? && set.reps.to_i.positive? }
        .sum { |set| set.weight.to_f * set.reps }
        .round(1)
    end

    # Total active time over completed working sets, in seconds.
    def active_seconds(sets)
      sets
        .select { |set| set.done? && set.kind == "working" && set.duration_seconds.to_i.positive? }
        .sum(&:duration_seconds)
    end

    # Fraction of prescribed sets actually checked off, 0.0..1.0.
    def completion(sets)
      return 0.0 if sets.empty?

      done = sets.count(&:done?).to_f
      (done / sets.size).round(2)
    end

    def hit_ratio(sets, target_reps)
      top = Gym::RepRange.top(target_reps || 5)
      working = sets.select { |set| set.done? && set.kind == "working" && set.reps.to_i.positive? }
      return nil if working.empty?

      hits = working.count { |set| set.reps.to_i >= top }.to_f
      (hits / working.size).round(2)
    end
  end
end
