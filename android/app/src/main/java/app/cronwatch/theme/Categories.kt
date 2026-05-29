package app.cronwatch.theme

import androidx.compose.ui.graphics.Color

data class Category(val key: String, val label: String, val color: Color)

object Categories {
    val all: List<Category> = listOf(
        Category("work", "Work", Color(0xFF3D6F8E)),
        Category("deep", "Deep", Color(0xFF4F7A6A)),
        Category("meeting", "Meeting", Color(0xFFB07845)),
        Category("study", "Study", Color(0xFF8A6FA3)),
        Category("exercise", "Exercise", Color(0xFFC8412C)),
        Category("sleep", "Sleep", Color(0xFF5C5C58)),
        Category("meal", "Meal", Color(0xFFE8A33D)),
        Category("break", "Break", Color(0xFFA8A89D)),
        Category("commute", "Commute", Color(0xFF7A8A95)),
        Category("entertain", "Entertain", Color(0xFFA05B7E)),
        Category("personal", "Personal", Color(0xFF9C8855)),
    )

    private val byKey: Map<String, Category> = all.associateBy { it.key }

    private val fallback = Palette.muted

    fun colorFor(key: String): Color {
        byKey[key]?.let { return it.color }
        val lower = key.lowercase()
        all.firstOrNull { it.label.equals(lower, ignoreCase = true) }?.let { return it.color }
        all.firstOrNull { it.key.equals(lower, ignoreCase = true) }?.let { return it.color }
        return fallback
    }

    fun labelFor(key: String): String {
        byKey[key]?.let { return it.label }
        val lower = key.lowercase()
        all.firstOrNull { it.label.equals(lower, ignoreCase = true) }?.let { return it.label }
        return key.ifBlank { "Entry" }
    }

    fun pillBackgroundFor(key: String): Color = colorFor(key).copy(alpha = 0.12f)
}
