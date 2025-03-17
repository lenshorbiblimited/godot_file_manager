extends Control

# Основные компоненты UI
@onready var file_tree: Tree = $MainContainer/MainArea/FileTree
@onready var file_list: ItemList = $MainContainer/MainArea/FileList
@onready var path_line: LineEdit = $MainContainer/TopPanel/HBoxContainer/PathLine
@onready var search_box: LineEdit = $MainContainer/TopPanel/HBoxContainer/SearchBox

# Кнопки навигации
@onready var back_button: Button = $MainContainer/TopPanel/HBoxContainer/NavigationPanel/BackButton
@onready var forward_button: Button = $MainContainer/TopPanel/HBoxContainer/NavigationPanel/ForwardButton
@onready var up_button: Button = $MainContainer/TopPanel/HBoxContainer/NavigationPanel/UpButton
@onready var refresh_button: Button = $MainContainer/TopPanel/HBoxContainer/NavigationPanel/RefreshButton
@onready var new_folder_button: Button = $MainContainer/TopPanel/HBoxContainer/ActionPanel/NewFolderButton
@onready var delete_button: Button = $MainContainer/TopPanel/HBoxContainer/ActionPanel/DeleteButton
@onready var copy_button: Button = $MainContainer/TopPanel/HBoxContainer/ActionPanel/CopyButton
@onready var paste_button: Button = $MainContainer/TopPanel/HBoxContainer/ActionPanel/PasteButton

# Водяной знак и активация
@onready var watermark_label: Label
@onready var watermark_container: HBoxContainer
@onready var activate_button: Button

# Путь к файлу с состоянием активации
const ACTIVATION_FILE = "user://activation_state.dat"

# История навигации
var history: Array[String] = []
var current_history_index: int = -1
var max_history_size: int = 50

# Текущий путь и буфер обмена
var current_path: String = ""
var clipboard_path: String = ""
var clipboard_is_cut: bool = false

func _ready() -> void:
	# Инициализация UI компонентов
	setup_ui()
	if not is_activated():
		setup_watermark()
	# Загрузка начальной директории
	navigate_to("C:/")

func setup_ui() -> void:
	if file_tree and file_list and path_line and search_box:
		# Настройка дерева файлов
		file_tree.hide_root = true
		file_tree.connect("item_selected", _on_tree_item_selected)
		
		# Настройка списка файлов
		file_list.connect("item_activated", _on_file_activated)
		file_list.connect("item_selected", _on_file_selected)
		
		# Настройка строки пути
		path_line.connect("text_submitted", _on_path_submitted)
		
		# Настройка поиска
		search_box.connect("text_changed", _on_search_changed)
		
		# Настройка кнопок навигации
		back_button.connect("pressed", _on_back_pressed)
		forward_button.connect("pressed", _on_forward_pressed)
		up_button.connect("pressed", _on_up_pressed)
		refresh_button.connect("pressed", _on_refresh_pressed)
		
		# Настройка кнопок действий
		new_folder_button.connect("pressed", _on_new_folder_pressed)
		delete_button.connect("pressed", _on_delete_pressed)
		copy_button.connect("pressed", _on_copy_pressed)
		paste_button.connect("pressed", _on_paste_pressed)
		
		# Добавляем подсказки для кнопок
		back_button.tooltip_text = "Назад (Alt + Backspace)"
		forward_button.tooltip_text = "Вперед (Alt + →)"
		up_button.tooltip_text = "Вверх (Alt + ↑)"
		refresh_button.tooltip_text = "Обновить (F5)"
		path_line.tooltip_text = "Путь (Ctrl + L)"
		search_box.tooltip_text = "Поиск (Ctrl + F)"
		new_folder_button.tooltip_text = "Новая папка (Ctrl + N)"
		delete_button.tooltip_text = "Удалить (Delete)"
		copy_button.tooltip_text = "Копировать (Ctrl + C)"
		paste_button.tooltip_text = "Вставить (Ctrl + V)"
		
		update_navigation_buttons()
		update_action_buttons()

func setup_watermark() -> void:
	# Создаём контейнер для водяного знака и кнопки
	watermark_container = HBoxContainer.new()
	watermark_container.anchor_left = 1
	watermark_container.anchor_top = 1
	watermark_container.anchor_right = 1
	watermark_container.anchor_bottom = 1
	watermark_container.offset_left = -600
	watermark_container.offset_top = -120
	watermark_container.offset_right = -20
	watermark_container.offset_bottom = -20
	watermark_container.alignment = BoxContainer.ALIGNMENT_END
	add_child(watermark_container)
	
	# Создаём вертикальный контейнер для текста и кнопки
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	watermark_container.add_child(vbox)
	
	# Водяной знак
	watermark_label = Label.new()
	watermark_label.text = "Lenshor Bib Limited"
	watermark_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.8))
	watermark_label.add_theme_font_size_override("font_size", 48)
	watermark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(watermark_label)
	
	# Кнопка активации
	activate_button = Button.new()
	activate_button.text = "Активировать"
	activate_button.custom_minimum_size = Vector2(200, 40)
	activate_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	activate_button.connect("pressed", _on_activate_pressed)
	vbox.add_child(activate_button)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BACKSPACE and event.alt_pressed:
			# Alt + Backspace = Назад
			_on_back_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT and event.alt_pressed:
			# Alt + Right = Вперед
			_on_forward_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP and event.alt_pressed:
			# Alt + Up = Вверх
			_on_up_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F5:
			# F5 = Обновить
			_on_refresh_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_L and event.ctrl_pressed:
			# Ctrl + L = Фокус на строку пути
			path_line.grab_focus()
			path_line.select_all()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F and event.ctrl_pressed:
			# Ctrl + F = Фокус на поиск
			search_box.grab_focus()
			search_box.select_all()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_N and event.ctrl_pressed:
			# Ctrl + N = Новая папка
			_on_new_folder_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DELETE:
			# Delete = Удалить
			_on_delete_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_C and event.ctrl_pressed:
			# Ctrl + C = Копировать
			_on_copy_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_V and event.ctrl_pressed:
			# Ctrl + V = Вставить
			_on_paste_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_X and event.ctrl_pressed:
			# Ctrl + X = Вырезать
			_on_copy_pressed(true)
			get_viewport().set_input_as_handled()

func navigate_to(path: String, add_to_history: bool = true) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
		
	if add_to_history:
		# Добавляем текущий путь в историю
		if current_history_index < history.size() - 1:
			# Удаляем все пути после текущего
			history = history.slice(0, current_history_index + 1)
		
		history.append(path)
		if history.size() > max_history_size:
			history.pop_front()
		
		current_history_index = history.size() - 1
		
	current_path = path
	path_line.text = current_path
	
	# Очистка списка файлов
	file_list.clear()
	
	var dir = DirAccess.open(path)
	if dir:
		# Получение списка файлов и директорий
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not file_name.begins_with("."):
				var full_path = path.path_join(file_name)
				var is_dir = dir.current_is_dir()
				
				# Добавление элемента в список
				file_list.add_item(file_name)
				var icon_index = file_list.get_item_count() - 1
				
			file_name = dir.get_next()
		dir.list_dir_end()
	
	update_navigation_buttons()
	update_action_buttons()

func update_navigation_buttons() -> void:
	back_button.disabled = current_history_index <= 0
	forward_button.disabled = current_history_index >= history.size() - 1
	up_button.disabled = current_path == "C:/" # Для Windows

func update_action_buttons() -> void:
	var has_selection = file_list.get_selected_items().size() > 0
	delete_button.disabled = not has_selection
	copy_button.disabled = not has_selection
	paste_button.disabled = clipboard_path.is_empty()

func _on_back_pressed() -> void:
	if current_history_index > 0:
		current_history_index -= 1
		navigate_to(history[current_history_index], false)

func _on_forward_pressed() -> void:
	if current_history_index < history.size() - 1:
		current_history_index += 1
		navigate_to(history[current_history_index], false)

func _on_up_pressed() -> void:
	var parent_path = current_path.get_base_dir()
	if parent_path != current_path:
		navigate_to(parent_path)

func _on_refresh_pressed() -> void:
	navigate_to(current_path, false)

func _on_file_activated(index: int) -> void:
	var item_name = file_list.get_item_text(index)
	var full_path = current_path.path_join(item_name)
	
	if DirAccess.dir_exists_absolute(full_path):
		# Если это директория, открываем её
		navigate_to(full_path)
	else:
		# Если это файл, открываем его через проводник Windows
		OS.shell_open(full_path)

func _on_file_selected(_index: int) -> void:
	update_action_buttons()

func _on_tree_item_selected() -> void:
	var selected = file_tree.get_selected()
	if selected:
		var path = get_item_path(selected)
		navigate_to(path)

func _on_path_submitted(new_path: String) -> void:
	if DirAccess.dir_exists_absolute(new_path):
		navigate_to(new_path)
	else:
		path_line.text = current_path

func _on_search_changed(search_text: String) -> void:
	if search_text.is_empty():
		navigate_to(current_path, false)
		return
	
	file_list.clear()
	var dir = DirAccess.open(current_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not file_name.begins_with(".") and file_name.to_lower().contains(search_text.to_lower()):
				var is_dir = dir.current_is_dir()
				file_list.add_item(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

func _on_new_folder_pressed() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Новая папка"
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Введите имя папки:"
	vbox.add_child(label)
	
	var line_edit = LineEdit.new()
	vbox.add_child(line_edit)
	
	dialog.ok_button_text = "Создать"
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func():
		var folder_name = line_edit.text
		if not folder_name.is_empty():
			var dir = DirAccess.open(current_path)
			if dir:
				dir.make_dir(folder_name)
				navigate_to(current_path, false)
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()

func _on_delete_pressed() -> void:
	var selected = file_list.get_selected_items()
	if selected.is_empty():
		return
		
	var item_name = file_list.get_item_text(selected[0])
	var full_path = current_path.path_join(item_name)
	
	var dialog = ConfirmationDialog.new()
	dialog.title = "Подтверждение удаления"
	dialog.dialog_text = "Вы уверены, что хотите удалить '%s'?" % item_name
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func():
		var dir = DirAccess.open(current_path)
		if dir:
			if DirAccess.dir_exists_absolute(full_path):
				DirAccess.remove_absolute(full_path)
			else:
				dir.remove(full_path.get_file())
			navigate_to(current_path, false)
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()

func _on_copy_pressed(cut: bool = false) -> void:
	var selected = file_list.get_selected_items()
	if selected.is_empty():
		return
		
	var item_name = file_list.get_item_text(selected[0])
	clipboard_path = current_path.path_join(item_name)
	clipboard_is_cut = cut
	update_action_buttons()

func _on_paste_pressed() -> void:
	if clipboard_path.is_empty():
		return
		
	var source_name = clipboard_path.get_file()
	var target_path = current_path.path_join(source_name)
	
	if clipboard_path == target_path:
		# Копирование в ту же папку - создаём копию
		var base_name = source_name.get_basename()
		var extension = source_name.get_extension()
		var new_name = base_name + " - копия"
		if not extension.is_empty():
			new_name += "." + extension
		target_path = current_path.path_join(new_name)
	
	# Проверяем существование исходного файла/папки
	if not (DirAccess.dir_exists_absolute(clipboard_path) or FileAccess.file_exists(clipboard_path)):
		clipboard_path = ""
		clipboard_is_cut = false
		update_action_buttons()
		return
	
	# Проверяем доступ к целевой директории
	var target_dir = DirAccess.open(current_path)
	if not target_dir:
		return
	
	if DirAccess.dir_exists_absolute(clipboard_path):
		# Копирование директории
		var err = DirAccess.make_dir_recursive_absolute(target_path)
		if err == OK:
			copy_directory_contents(clipboard_path, target_path)
	else:
		# Копирование файла
		var source_file = FileAccess.open(clipboard_path, FileAccess.READ)
		if source_file:
			var target_file = FileAccess.open(target_path, FileAccess.WRITE)
			if target_file:
				target_file.store_buffer(source_file.get_buffer(source_file.get_length()))
				target_file.close()
			source_file.close()
	
	if clipboard_is_cut:
		# Если это было перемещение, удаляем оригинал
		if DirAccess.dir_exists_absolute(clipboard_path):
			remove_directory_recursive(clipboard_path)
		else:
			var dir = DirAccess.open(clipboard_path.get_base_dir())
			if dir:
				dir.remove(clipboard_path.get_file())
		clipboard_path = ""
		clipboard_is_cut = false
	
	navigate_to(current_path, false)

# Рекурсивное копирование содержимого директории
func copy_directory_contents(from_dir: String, to_dir: String) -> void:
	var dir = DirAccess.open(from_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name != "." and file_name != "..":
				var source_path = from_dir.path_join(file_name)
				var target_path = to_dir.path_join(file_name)
				
				if DirAccess.dir_exists_absolute(source_path):
					# Копируем поддиректорию
					DirAccess.make_dir_recursive_absolute(target_path)
					copy_directory_contents(source_path, target_path)
				else:
					# Копируем файл
					var source_file = FileAccess.open(source_path, FileAccess.READ)
					if source_file:
						var target_file = FileAccess.open(target_path, FileAccess.WRITE)
						if target_file:
							target_file.store_buffer(source_file.get_buffer(source_file.get_length()))
							target_file.close()
						source_file.close()
			
			file_name = dir.get_next()
		
		dir.list_dir_end()

# Рекурсивное удаление директории
func remove_directory_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name != "." and file_name != "..":
				var target = path.path_join(file_name)
				if DirAccess.dir_exists_absolute(target):
					remove_directory_recursive(target)
				else:
					dir.remove(file_name)
			file_name = dir.get_next()
		
		dir.list_dir_end()
		DirAccess.remove_absolute(path)

func get_item_path(item: TreeItem) -> String:
	var path = ""
	while item:
		path = item.get_text(0).path_join(path)
		item = item.get_parent()
	return path

func _on_activate_pressed() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Активация"
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Введите пароль:"
	vbox.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.secret = true # Скрываем вводимый текст
	vbox.add_child(line_edit)
	
	dialog.ok_button_text = "Активировать"
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func():
		if line_edit.text == "Explorer":
			save_activation_state()
			watermark_container.queue_free()
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()

func save_activation_state() -> void:
	var file = FileAccess.open(ACTIVATION_FILE, FileAccess.WRITE)
	if file:
		file.store_string("activated")
		file.close()

func is_activated() -> bool:
	if FileAccess.file_exists(ACTIVATION_FILE):
		var file = FileAccess.open(ACTIVATION_FILE, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			return content == "activated"
	return false
