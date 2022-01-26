tool
extends WindowDialog


signal title_chosen(title)


const TitleList = preload("res://addons/dialogue_manager/components/title_list.gd")


var chosen_title: String = ""


onready var title_list: TitleList = $Margin/VBox/TitleList


func choose_a_title(titles: Array) -> void:
	title_list.titles = titles
	popup_centered()
	title_list.focus_filter()


### Signals


func _on_TitleList_title_clicked(title):
	chosen_title = title


func _on_TitleList_title_dbl_clicked(title):
	# Consume the double click so our selection behind the dialog doesn't change
	yield(get_tree(), "idle_frame")
	emit_signal("title_chosen", title)
	hide()


func _on_ChooseButton_pressed():
	emit_signal("title_chosen", chosen_title)
	hide()


func _on_CancelButton_pressed():
	hide()
