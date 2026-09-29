extends "res://scenes/dev/foundation_dialogue_progression_capture.gd"
## Same actual normal route and assertions; wait for the new bounded contact action,
## not an immediate grant four frames after path arrival. No retry/input injection.
var harvest_receipts: Dictionary = {}
func tap_object(node: Node) -> bool:
	var is_resource:bool=node is Gatherable and node.can_gather()
	var item:String=node.item_id if is_resource else ""
	var start_count:=Inventory.count(item) if is_resource else 0
	var ok:bool=await super.tap_object(node)
	if not ok or not is_resource:return ok
	var driver:Node=interaction._harvest
	print("HARVEST_NORMAL_ARRIVAL ",JSON.stringify({"item":item,"count":Inventory.count(item),"before":start_count,"token":driver.token,"elapsed":driver.elapsed,"state":driver.state.inspect_state()}))
	var kind:String=driver.material_for(item)
	var capture_this:=not harvest_receipts.has(kind)
	if capture_this:
		harvest_receipts[kind]=true
		await _capture("harvest-%s-arrival.png"%kind,"normal_harvest_"+kind+"_arrival")
	var deadline:=Time.get_ticks_msec()+1200
	while driver.token!=0 and Time.get_ticks_msec()<deadline:await _physics_frames(1)
	if not require(driver.token==0,"bounded contact action resolves "+item):return false
	if capture_this:
		await _capture("harvest-%s-response.png"%kind,"normal_harvest_"+kind+"_response")
	return require(Inventory.count(item)>start_count,"normal action contact actually rewards "+item)
