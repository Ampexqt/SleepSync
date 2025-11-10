class NotificationService {
  bool _enabled = false;

  bool get isEnabled => _enabled;

  void setEnabled(bool value) {
    _enabled = value;
  }
}
