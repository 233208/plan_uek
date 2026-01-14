import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Personalizacja"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. PRESETY
          const Text("Gotowe motywy", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: appPresets.length,
              itemBuilder: (context, index) {
                final preset = appPresets[index];
                bool isSelected = 
                    themeProvider.themeMode == preset.mode && 
                    themeProvider.primaryColor.value == preset.primaryColor.value; // Simple check

                return GestureDetector(
                  onTap: () => themeProvider.applyPreset(preset),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: preset.mode == ThemeMode.dark ? (preset.backgroundColor ?? const Color(0xFF1E1E1E)) : (preset.backgroundColor ?? Colors.white),
                      border: Border.all(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                         BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0,2))
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(preset.icon, color: preset.primaryColor, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          preset.name, 
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: preset.mode == ThemeMode.dark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          )
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),

          // 1.5 KOLORY ZAJĘĆ
          const Text("Kolory zajęć", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Column(
            children: [
               _buildColorRow(context, "Wykład", themeProvider.lectureColor, themeProvider.setLectureColor),
               _buildColorRow(context, "Ćwiczenia", themeProvider.exerciseColor, themeProvider.setExerciseColor),
               _buildColorRow(context, "Laboratorium", themeProvider.labColor, themeProvider.setLabColor),
               _buildColorRow(context, "Zdalne", themeProvider.remoteColor, themeProvider.setRemoteColor),
            ],
          ),

          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),

          // 2. TRYB (JASNY/CIEMNY)
          const Text("Tryb", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.wb_sunny), label: Text("Jasny")),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.nightlight_round), label: Text("Ciemny")),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_system_daydream), label: Text("System")),
            ],
            selected: {themeProvider.themeMode},
            onSelectionChanged: (Set<ThemeMode> newSelection) {
              themeProvider.setThemeMode(newSelection.first);
            },
          ),

          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),

          // 3. DOSTOSUJ KOLOR WIODĄCY
          const Text("Kolor wiodący", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
      Colors.black, Colors.white, Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
      Colors.brown, Colors.grey, Colors.blueGrey,  
      Colors.tealAccent, Colors.cyanAccent, Colors.lightBlueAccent, Colors.indigoAccent,
      Colors.deepPurpleAccent, Colors.purpleAccent, Colors.pinkAccent, Colors.redAccent,
            ].map((color) {
              bool isSelected = themeProvider.primaryColor.value == color.value;
              return GestureDetector(
                onTap: () => themeProvider.setPrimaryColor(color),
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3) : null,
                    boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 2)],
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 40),
          Center(
             child: Text("Totalna Personalizacja", style: TextStyle(color: Colors.grey[400], letterSpacing: 2, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildColorRow(BuildContext context, String label, Color currentColor, Function(Color) onColorChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          GestureDetector(
            onTap: () {
               _showColorPicker(context, currentColor, onColorChanged);
            },
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey, width: 1),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, Color currentColor, Function(Color) onColorChanged) {
    final List<Color> colors = [
      Colors.black, Colors.white, Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
      Colors.brown, Colors.grey, Colors.blueGrey,  
      Colors.tealAccent, Colors.cyanAccent, Colors.lightBlueAccent, Colors.indigoAccent,
      Colors.deepPurpleAccent, Colors.purpleAccent, Colors.pinkAccent, Colors.redAccent
    ];

    showDialog(
      context: context, 
      builder: (context) {
        return AlertDialog(
          title: const Text("Wybierz kolor"),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: colors.map((color) => GestureDetector(
              onTap: () {
                onColorChanged(color);
                Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: color.value == currentColor.value ? Border.all(color: Colors.black, width: 3) : null
                ),
              ),
            )).toList(),
          ),
        );
      }
    );
  }
}
