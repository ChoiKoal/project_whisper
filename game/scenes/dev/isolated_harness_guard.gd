extends RefCounted
## Safety gate for destructive dev harnesses. Direct editor execution has no sentinel and fails
## closed before touching `user://`. Runners must bind the exact isolated HOME root explicitly.

const ENV_TEST_HOME := "WHISPER_TEST_HOME"


static func require_isolated_user_data(harness_name: String) -> bool:
	var expected_root := OS.get_environment(ENV_TEST_HOME).simplify_path()
	var user_dir := ProjectSettings.globalize_path("user://").simplify_path()
	var valid := false
	if expected_root.is_absolute_path() and expected_root.length() >= 8:
		var prefix := expected_root + "/" if not expected_root.ends_with("/") else expected_root
		valid = user_dir == expected_root or user_dir.begins_with(prefix)
	if not valid:
		push_error("%s refused destructive user:// access: set %s to the isolated HOME root (user_dir=%s)" % [
			harness_name, ENV_TEST_HOME, user_dir])
	return valid
