# Исходник героя

`hobbit.glb` — оригинальная low-poly модель этого проекта. Она создана в Blender 5.3 скриптом `tools/generate_hobbit.py`, не содержит скачанных моделей или текстур. Геометрия, материалы и узлы конечностей экспортируются в GLB; физическая коллизия и анимация задаются отдельно в Godot.

Повторная генерация из корня проекта:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.3\blender.exe' --background --python tools/generate_hobbit.py
```

После генерации Godot переимпортирует GLB. Анимация в `scripts/hero_visual.gd` ожидает узлы `Torso`, `LegLeft`, `LegRight`, `ArmLeft`, `ArmRight`; их имена нужно сохранять. Направление лица — локальный +Z, уровень подошв — Y = 0. Файл GLB можно импортировать в Blender для ручной доработки; повторный запуск генератора заменит его.
