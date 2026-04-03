# Expense Tracker

A personal expense tracker app built with Flutter. Log daily expenses by category, set monthly income, and view spending reports with date range filtering and pie chart breakdowns.

## Features

- Add daily expenses with amount, category, date, and optional note
- 6 built-in categories: Food, Clothes, Travel, Lending, Investment, Received
- Set monthly income to track remaining balance
- Swipe-to-delete expenses
- Reports with date range filter
- Category-wise spending breakdown with pie chart
- All data stored locally on device (SQLite)

## Setup

### Prerequisites

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. Ensure you have Xcode installed (for iOS) or Android Studio (for Android)

### Getting Started

```bash
cd expense_tracker

# Generate platform-specific files (ios/, android/, etc.)
flutter create .

# Install dependencies
flutter pub get

# Run on iOS simulator
flutter run

# Or run on a specific device
flutter devices        # list available devices
flutter run -d <device_id>
```

### Build for iOS

```bash
flutter build ios
```

## Project Structure

```
lib/
  main.dart                  - App entry, theme, provider setup
  models/
    expense.dart             - Expense data model
    income.dart              - Income data model
  db/
    database_helper.dart     - SQLite CRUD operations
  providers/
    expense_provider.dart    - Expense state management
    income_provider.dart     - Income state management
  screens/
    home_screen.dart         - Dashboard with summary & expense list
    add_expense_screen.dart  - Add expense form
    income_screen.dart       - Set monthly income
    report_screen.dart       - Date range reports with pie chart
  widgets/
    category_chip.dart       - Category selector widget
    expense_tile.dart        - Expense list item
    summary_card.dart        - Income/spent/balance card
  constants/
    categories.dart          - Category definitions (name, icon, color)
```
