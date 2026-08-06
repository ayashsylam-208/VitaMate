from django.urls import path

from notification_hub.api.views import (
    NotificationDeviceRegisterView,
    NotificationDevicesView,
    NotificationPrimaryDeviceView,
    NotificationPreferencesView,
    NotificationReportView,
    NotificationSyncView,
)


urlpatterns = [
    path("devices/register/", NotificationDeviceRegisterView.as_view(), name="notification-hub-device-register"),
    path("devices/", NotificationDevicesView.as_view(), name="notification-hub-devices"),
    path("devices/primary/", NotificationPrimaryDeviceView.as_view(), name="notification-hub-primary-device"),
    path("preferences/", NotificationPreferencesView.as_view(), name="notification-hub-preferences"),
    path("sync/", NotificationSyncView.as_view(), name="notification-hub-sync"),
    path("report/", NotificationReportView.as_view(), name="notification-hub-report"),
]
