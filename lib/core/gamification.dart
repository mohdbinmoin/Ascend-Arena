import 'dart:math';

class Gamification {
  // Neverending level curve. E.g. Level 1 -> 0 XP, Level 2 -> 100 XP, Level 3 -> 400 XP, etc.
  static int calculateLevel(int totalXp) {
    return (sqrt(totalXp / 100)).floor() + 1;
  }
  
  static int calculateXpRequiredForLevel(int level) {
    return pow(level - 1, 2).toInt() * 100;
  }

  // Calculate XP gained from a task score
  static int calculateTaskXp(num score, num maxScore, String timingStatus) {
    int baseParticipation = timingStatus == 'on_time' ? 50 : 25; // Less for late
    double percentage = (score / maxScore);
    int performanceXp = (percentage * 100).round();
    
    return baseParticipation + performanceXp;
  }
}
