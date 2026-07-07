# tick_hit_outcome.gd
# Typed hit-result value object for tick combat's resolver seam: TickHitResolver returns instances of
# this class instead of dictionaries, and enemy/action/preview consumers read named fields and compare
# FeedbackKind/MajorTrigger enums instead of string-keyed lookups with silent defaults. The outcome
# crosses the real resolver/enemy/action/preview module boundary, unlike the target snapshot, which
# stays a resolver-input adapter dictionary. A default-constructed instance is the empty/whiff outcome.
class_name TickHitOutcome
extends RefCounted

enum FeedbackKind {
    WHIFF,
    BLOCKED,
    DAMAGED,
    GUARD_BREAK,
    STAGGER_BURST,
    KILL,
}

## Distinguishes a mobility-slot-triggered Major's upgraded result from a generic guard break or kill,
## so presentation can show distinct feedback while the fallback feedback still fires.
enum MajorTrigger {
    NONE,
    GUARD_SHREDDER,
    EXECUTION,
}

# -- State --

var angle: DirectionResolver.HitAngle = DirectionResolver.HitAngle.NONE
var was_guarded := false
var staggered := false
var guard_broken := false
var stagger_burst := false
var killed := false
var hp_damage := 0.0
var guard_damage := 0
var feedback_kind := FeedbackKind.WHIFF
var major_trigger := MajorTrigger.NONE
