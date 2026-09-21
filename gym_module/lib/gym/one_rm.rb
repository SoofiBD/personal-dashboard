module Gym
  # Estimated one-rep max. Ported from openGym's onerm.js (AGPL-3.0) and
  # deliberately decoupled from the exercise catalog: an estimate only needs a
  # weight and a rep count, so timed and cardio sets never reach it.
  #
  # Epley is the default because it is the one most lifters know; the formulas
  # agree closely at low reps and diverge as reps rise, which is why REP_CAP
  # exists. Refusing to guess beats printing a fantasy number.
  module OneRm
    REP_CAP = 12
    DEFAULT_FORMULA = :epley

    FORMULAS = {
      epley: ->(w, r) { w * (1 + r / 30.0) },
      brzycki: ->(w, r) { w * 36.0 / (37 - r) },
      lombardi: ->(w, r) { w * (r**0.10) }
    }.freeze

    module_function

    def estimate(weight, reps, formula: DEFAULT_FORMULA)
      w = weight.to_f
      r = reps.to_i
      return nil if w <= 0 || r < 1 || r > REP_CAP

      fn = FORMULAS.fetch(formula) { FORMULAS.fetch(DEFAULT_FORMULA) }
      est = if r == 1
        w
      else
        fn.call(w, r)
      end
      return nil unless est.finite? && est.positive?

      (est * 10).round / 10.0
    end

    # Best estimate across completed working sets (a single relation or array).
    def best_set_of(sets)
      sets
        .select { |set| set.done? && set.kind == "working" }
        .filter_map do |set|
          est = estimate(set.weight, set.reps)
          next nil unless est

          {estimate: est, weight: set.weight.to_f, reps: set.reps}
        end
        .max_by { |entry| entry[:estimate] }
    end
  end
end
