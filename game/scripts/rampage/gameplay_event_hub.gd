class_name GameplayEventHub
extends Node

signal event_published(event: GameplayEvent)

var _next_event_id: int = 1
var _dedupe_keys: Dictionary[StringName, bool] = {}
var _accepted_events: Dictionary[int, GameplayEvent] = {}


func accept(event: GameplayEvent) -> bool:
	if event == null:
		return false
	if not event.dedupe_key.is_empty() and _dedupe_keys.has(event.dedupe_key):
		return false
	event.event_id = _next_event_id
	_next_event_id += 1
	if not event.dedupe_key.is_empty():
		_dedupe_keys[event.dedupe_key] = true
	_accepted_events[event.event_id] = event
	return true


func broadcast(event: GameplayEvent) -> void:
	if event == null or not _accepted_events.has(event.event_id):
		return
	if _accepted_events[event.event_id] != event:
		return
	event_published.emit(event)
	_accepted_events.erase(event.event_id)


func reset_run() -> void:
	_dedupe_keys.clear()
	_accepted_events.clear()
