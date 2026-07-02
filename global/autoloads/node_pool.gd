# node_pool.gd
# Unified spawn pool for the action-rpg preset. Acquire/release a single API for
# both pooled and fresh instantiation, so spawn-heavy entities (projectiles, hit
# numbers, common enemies) avoid per-frame instantiation spikes.
#
# Pooled nodes are cached by scene resource_path and reused. On acquire, reset() is
# called; on release, set_enabled(false) is called and the node is parked. These are
# the Component lifecycle hooks (see component_architecture.md).
extends Node

## resource_path -> Array[Node] of parked instances.
var _pool: Dictionary = { }
## node -> resource_path, so release() doesn't need the scene passed again.
var _node_key: Dictionary = { }


## Pre-instantiates [param count] instances of [param scene] into the pool. Call
## during a loading screen to avoid first-use spikes.
func prewarm(scene: PackedScene, count: int, parent: Node) -> void:
    for i in count:
        release(acquire(scene, parent, true))


## Acquires a node for [param scene], parented to [param parent]. When [param pooled],
## reuses a parked instance if one exists; otherwise instantiates fresh. reset() is
## called before the node is returned.
func acquire(scene: PackedScene, parent: Node, pooled: bool = true) -> Node:
    var key := scene.resource_path
    var node: Node = null
    if pooled and _pool.has(key):
        var parked: Array = _pool[key]
        while not parked.is_empty():
            var candidate: Node = parked.pop_back()
            if is_instance_valid(candidate):
                node = candidate
                break
    if node == null:
        node = scene.instantiate()
    _node_key[node] = key
    parent.add_child(node)
    if node.has_method("reset"):
        node.reset()
    return node


## Returns [param node] to its pool and detaches it from its parent. set_enabled(false)
## parks it cheaply without freeing. Nodes not acquired here are freed instead.
func release(node: Node) -> void:
    if not _node_key.has(node):
        ToastManager.show_warning("NodePool.release: node not acquired through the pool — freeing")
        node.queue_free()
        return
    var key: String = _node_key[node]
    if node.has_method("set_enabled"):
        node.set_enabled(false)
    if node.get_parent() != null:
        node.get_parent().call_deferred("remove_child", node)
    if not _pool.has(key):
        _pool[key] = []
    _pool[key].append(node)
