class_name Scheduler
extends RefCounted

## Energy-based turn order.
##
## Game time advances ONLY through here, never on a rendered frame. Godot's
## _process loop drives animation and input; it must never drive the
## simulation, or the game stops being turn-based in subtle ways that are
## miserable to debug later.

const ACTION_COST := 100

## Returns the next actor entitled to act, ticking energy until someone is.
static func next_actor(actors: Array) -> Entity:
	var living := []
	for a in actors:
		if a.alive:
			living.append(a)
	if living.is_empty():
		return null

	# Bounded so a pathological speed of 0 cannot hang the game.
	for _guard in 1000:
		var best: Entity = null
		for a in living:
			if a.energy >= ACTION_COST and (best == null or a.energy > best.energy):
				best = a
		if best != null:
			return best
		for a in living:
			a.energy += a.speed
	return null

## Actions may cost more than the standard stride -- wading, or hauling
## yourself through mud. The cost is on the ACTION so that difficult ground
## slows travel without slowing anything else the actor does.
static func spend(actor: Entity, cost: int = ACTION_COST) -> void:
	actor.energy -= maxi(1, cost)
