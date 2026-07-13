extends Node

var cache: Dictionary = {}

func store(path: String, resource: Resource) -> void:
	if resource != null:
		cache[path] = resource

func get_resource(path: String) -> Resource:
	return cache.get(path)

