class_name Toast
## Petites confirmations à l'écran, appelables depuis n'importe quel module : Toast.say("Copié").

static var ui: AppUI


static func say(txt: String) -> void:
	if ui:
		ui.toast(txt)
