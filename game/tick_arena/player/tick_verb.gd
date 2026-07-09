# tick_verb.gd
# Typed input-command value object for the tick arena's verb seam: TickInput emits instances of this
# class instead of dictionaries, and TickActionController matches on kind directly. Owns only the
# input command contract — kind, dir, mobility, repeat — never action legality, cooldown, or
# world-advance state; those stay owned by TickActionController.
class_name TickVerb
extends RefCounted

enum Kind {
    MOVE,
    CONFIRM,
    MODE_SET,
    CANCEL,
    WAIT,
}

# -- State --

var kind: Kind
var dir: Vector2i
var mobility: bool
var repeat: bool

# == Lifecycle ==


func _init(init_kind: Kind, init_dir := Vector2i.ZERO, init_mobility := false, init_repeat := false) -> void:
    kind = init_kind
    dir = init_dir
    mobility = init_mobility
    repeat = init_repeat

# == Common API ==


static func move(move_dir: Vector2i) -> TickVerb:
    return TickVerb.new(Kind.MOVE, move_dir)


static func confirm(is_repeat := false) -> TickVerb:
    return TickVerb.new(Kind.CONFIRM, Vector2i.ZERO, false, is_repeat)


static func mode_set(is_mobility: bool) -> TickVerb:
    return TickVerb.new(Kind.MODE_SET, Vector2i.ZERO, is_mobility)


static func cancel() -> TickVerb:
    return TickVerb.new(Kind.CANCEL)


static func wait() -> TickVerb:
    return TickVerb.new(Kind.WAIT)
