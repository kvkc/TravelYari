import 'package:hive_flutter/hive_flutter.dart';
import '../../features/trip_planning/models/trip.dart';
import '../../features/trip_planning/models/location.dart';
import '../../features/expenses/models/expense.dart';

class StorageService {
  static const String tripsBox = 'trips';
  static const String locationsBox = 'locations';
  static const String settingsBox = 'settings';
  static const String expensesBox = 'expenses';

  static late Box<Map> _tripsBox;
  static late Box<Map> _locationsBox;
  static late Box _settingsBox;
  static late Box<Map> _expensesBox;

  static Future<void> init() async {
    _tripsBox = await Hive.openBox<Map>(tripsBox);
    _locationsBox = await Hive.openBox<Map>(locationsBox);
    _settingsBox = await Hive.openBox(settingsBox);
    _expensesBox = await Hive.openBox<Map>(expensesBox);
  }

  // Trips
  static Future<void> saveTrip(Trip trip) async {
    await _tripsBox.put(trip.id, trip.toJson());
  }

  static Trip? getTrip(String id) {
    final data = _tripsBox.get(id);
    if (data == null) return null;
    return Trip.fromJson(Map<String, dynamic>.from(data));
  }

  static List<Trip> getAllTrips() {
    return _tripsBox.values
        .map((data) => Trip.fromJson(Map<String, dynamic>.from(data)))
        .toList();
  }

  static Future<void> deleteTrip(String id) async {
    await _tripsBox.delete(id);
  }

  // Locations (for caching searched locations)
  static Future<void> cacheLocation(TripLocation location) async {
    await _locationsBox.put(location.id, location.toJson());
  }

  static List<TripLocation> getCachedLocations() {
    return _locationsBox.values
        .map((data) => TripLocation.fromJson(Map<String, dynamic>.from(data)))
        .toList();
  }

  // Settings
  static Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  static T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as T?;
  }

  // Expenses
  static Future<void> saveExpense(Expense expense) async {
    await _expensesBox.put(expense.id, expense.toJson());
  }

  static Expense? getExpense(String id) {
    final data = _expensesBox.get(id);
    if (data == null) return null;
    return Expense.fromJson(Map<String, dynamic>.from(data));
  }

  static List<Expense> getTripExpenses(String tripId) {
    return _expensesBox.values
        .map((data) => Expense.fromJson(Map<String, dynamic>.from(data)))
        .where((e) => e.tripId == tripId)
        .toList()
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
  }

  static List<Expense> getAllExpenses() {
    return _expensesBox.values
        .map((data) => Expense.fromJson(Map<String, dynamic>.from(data)))
        .toList();
  }

  static Future<void> deleteExpense(String id) async {
    await _expensesBox.delete(id);
  }

  static Future<void> deleteTripExpenses(String tripId) async {
    final expenses = getTripExpenses(tripId);
    for (final expense in expenses) {
      await _expensesBox.delete(expense.id);
    }
  }
}
