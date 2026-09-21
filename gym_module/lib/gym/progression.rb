module Gym
  # Automatic progression. Ported from openGym's progression.js (AGPL-3.0).
  #
  # Pure function of the workout history: nothing writes back into a finished
  # workout. The next prescription is derived from the log every time it is
  # needed, so fixing a mistyped set immediately produces the right target.
  #
  # Reading a session honestly is the whole game:
  #   * a set checked off with at least its target reps -> hit
  #   * a set checked off with fewer reps               -> miss
  #   * a set never checked off                         -> miss
  #   * fewer sets than prescribed                      -> miss
  # So a session that fell apart can never advance the load as if it succeeded.
  class Progression
    DELOAD_FACTOR = 0.9
    DEFAULT_WEIGHT_STEP = 2.5
    DEFAULT_DURATION_STEP = 15
    POLICIES = %w[off linear greyskull double time].freeze

    attr_reader :reason

    # history_sets: completed working sets of the most recent finished session
    # for the exercise (chronological). Empty history means no prescription.
    def initialize(history_sets:, target_sets:, target_reps: nil, target_duration_seconds: nil,
      weight_step: DEFAULT_WEIGHT_STEP, duration_step: DEFAULT_DURATION_STEP)
      @history_sets = Array(history_sets)
      @target_sets = target_sets.to_i
      @target_reps = target_reps
      @target_duration = target_duration_seconds
      @weight_step = weight_step.to_f
      @duration_step = duration_step.to_i
      @reason = nil
    end

    # Returns {weight:, reps:, duration_seconds:} or nil when the target should
    # simply repeat. Sets @reason so the UI can show why it picked this weight.
    def next_target(policy)
      @reason = nil
      case policy.to_s
      when "linear" then linear
      when "greyskull" then greyskull
      when "double" then double
      when "time" then time
      end
    end

    private

    def performed_sets
      @performed_sets ||= @history_sets.select(&:done?)
    end

    def full_session?
      performed_sets.size >= @target_sets
    end

    def target_top
      @target_top ||= Gym::RepRange.top(@target_reps || 5)
    end

    def target_bottom
      @target_bottom ||= Gym::RepRange.bottom(@target_reps || 5)
    end

    def last_weight
      @last_weight ||= @history_sets.reverse.find { |set| set.weight.to_f.positive? }&.weight.to_f
    end

    def last_duration
      @last_duration ||= @history_sets.reverse.find { |set| set.duration_seconds.to_f.positive? }&.duration_seconds.to_i
    end

    # Linear: hit every rep in every prescribed set and the weight goes up.
    # Two consecutive misses (performed below target) trigger a deload.
    def linear
      return nil unless full_session?

      misses = performed_sets.count { |set| set.reps.to_i < target_top }
      if misses.zero?
        @reason = I18n.t("gym.progression.reasons.linear_up", reps: target_top, step: @weight_step, default: "Tüm setler #{target_top} tekrara ulaştı +#{@weight_step}kg")
        {weight: (last_weight + @weight_step).round(1), reps: target_bottom, duration_seconds: nil}
      elsif misses >= 2
        @reason = I18n.t("gym.progression.reasons.deload", default: "İki hedef altı set, %10 sökülme")
        {weight: (last_weight * DELOAD_FACTOR).round(1), reps: target_bottom, duration_seconds: nil}
      end
    end

    # Greyskull LP: two straight sets plus a final set taken to failure.
    # Beat the target on that set and the weight goes up — double if the reps
    # doubled. One failure resets 10 %.
    def greyskull
      return nil unless full_session?

      amrap = performed_sets.last
      reps = amrap.reps.to_i
      misses = performed_sets.select { |set| set.reps.to_i < target_top }
      if reps >= target_top * 2
        @reason = I18n.t("gym.progression.reasons.greyskull_double", default: "Son set hedefin iki katı +#{@weight_step * 2}kg")
        {weight: (last_weight + @weight_step * 2).round(1), reps: target_bottom, duration_seconds: nil}
      elsif reps >= target_top && misses.none?
        @reason = I18n.t("gym.progression.reasons.greyskull_up", step: @weight_step, default: "Son set hedefi geçti +#{@weight_step}kg")
        {weight: (last_weight + @weight_step).round(1), reps: target_bottom, duration_seconds: nil}
      elsif misses.any?
        @reason = I18n.t("gym.progression.reasons.greyskull_deload", default: "Başarısız set, %10 sökülme")
        {weight: (last_weight * DELOAD_FACTOR).round(1), reps: target_bottom, duration_seconds: nil}
      end
    end

    # Double progression: work through a rep range at the same weight. Reach
    # the top of the range in every set and the weight goes up, reps reset to
    # the bottom of the range.
    def double
      return nil unless full_session?

      if performed_sets.all? { |set| set.reps.to_i >= target_top }
        @reason = I18n.t("gym.progression.reasons.double_up", reps: target_top, step: @weight_step, default: "Aralığın tepesine ulaşıldı +#{@weight_step}kg")
        {weight: (last_weight + @weight_step).round(1), reps: target_bottom, duration_seconds: nil}
      end
    end

    # Timed holds: complete every prescribed set for the full duration and the
    # duration goes up.
    def time
      return nil unless full_session?

      if performed_sets.all? { |set| set.duration_seconds.to_i >= @target_duration.to_i }
        @reason = I18n.t("gym.progression.reasons.time_up", step: @duration_step, default: "Tüm setler tam sürede tutuldu +#{@duration_step}s")
        {weight: nil, reps: nil, duration_seconds: last_duration + @duration_step}
      end
    end
  end
end
