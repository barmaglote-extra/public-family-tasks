# AppDrawer Menu Features

## Overview
The AppDrawer has been updated to include two new menu items:

### 1. Settings
- **Icon**: Settings icon
- **Action**: Navigates to a Settings page
- **Location**: `/lib/pages/settings_page.dart`
- **Route**: `/settings`

The Settings page is currently a basic template where you can add specific configuration options later.

### 2. Buy me a coffee (Support)
- **Icon**: Coffee icon
- **Action**: Opens external donation URL in browser
- **Configuration**: Donation URL is configurable in `/lib/config/app_config.dart`

## Configuration

### Changing the Donation URL

To change the donation URL, edit the file `/lib/config/app_config.dart`:

```dart
static const String donationUrl = 'https://buymeacoffee.com/evgeniydans';
```

**Supported platforms:**
- Buy Me a Coffee: `https://www.buymeacoffee.com/yourusername`
- Ko-fi: `https://ko-fi.com/yourusername`
- Patreon: `https://www.patreon.com/yourusername`
- PayPal: `https://paypal.me/yourusername`
- Any other donation platform URL

### Adding Settings Options

To add specific settings to the Settings page, edit `/lib/pages/settings_page.dart` and add your configuration widgets in the body section.

## Technical Details

### Dependencies Added
- `url_launcher: ^6.0.0` - For opening external URLs

### Files Modified
- `/lib/app_drawer.dart` - Updated menu structure
- `/lib/main.dart` - Added settings route
- `/pubspec.yaml` - Added url_launcher dependency

### Files Created
- `/lib/config/app_config.dart` - Configuration file
- `/lib/pages/settings_page.dart` - Settings page
- `/MENU_FEATURES.md` - This documentation

## Usage

1. **Settings**: Tap "Settings" in the drawer to access the settings page
2. **Support**: Tap "Buy me a coffee" to open the donation URL in an external browser

The donation link will show an error message if the URL cannot be opened (e.g., no internet connection or invalid URL).