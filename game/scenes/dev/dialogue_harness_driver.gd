extends RefCounted
## Test-only reader. Actual dispatched input, no seen flags or direct advance calls.
static func read(scene: Node) -> bool:
	var panel:=scene.get_node_or_null("DialoguePanel") as DialoguePanel
	if panel==null:return false
	var tree:=scene.get_tree()
	for i in range(40):
		if not panel.is_open():return true
		var event:=InputEventAction.new()
		event.action="ui_accept";event.pressed=true
		tree.root.push_input(event,true)
		await tree.process_frame
		event.pressed=false;tree.root.push_input(event,true)
		await tree.process_frame
		await tree.process_frame
	return not panel.is_open()
