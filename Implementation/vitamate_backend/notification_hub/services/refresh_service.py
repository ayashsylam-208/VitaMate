class NotificationHubRefreshService:
    @staticmethod
    def refresh_user(*, user) -> None:
        del user
        # Notification plans are rebuilt on sync. This hook intentionally
        # exists to keep domain writers coupled to the hub boundary only.
        return None
