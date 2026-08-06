from django.urls import path

from manager.api.views import (
    ManagerAccountDeletionView,
    ManagerAvatarView,
    ManagerChangePasswordView,
    ManagerGoalDetailView,
    ManagerGoalsResetView,
    ManagerGoalsView,
    ManagerLogoutAllView,
    ManagerNotificationsView,
    ManagerOverviewView,
    ManagerPrivacyExportView,
    ManagerPrivacyView,
    ManagerSecurityView,
)


urlpatterns = [
    path("overview/", ManagerOverviewView.as_view(), name="manager-overview"),
    path("goals/", ManagerGoalsView.as_view(), name="manager-goals"),
    path("goals/reset/", ManagerGoalsResetView.as_view(), name="manager-goals-reset"),
    path("goals/<str:key>/", ManagerGoalDetailView.as_view(), name="manager-goal-detail"),
    path("notifications/", ManagerNotificationsView.as_view(), name="manager-notifications"),
    path("avatar/", ManagerAvatarView.as_view(), name="manager-avatar"),
    path("security/", ManagerSecurityView.as_view(), name="manager-security"),
    path("security/change-password/", ManagerChangePasswordView.as_view(), name="manager-change-password"),
    path("security/logout-all/", ManagerLogoutAllView.as_view(), name="manager-logout-all"),
    path("privacy/", ManagerPrivacyView.as_view(), name="manager-privacy"),
    path("privacy/export/", ManagerPrivacyExportView.as_view(), name="manager-privacy-export"),
    path("privacy/account-deletion/", ManagerAccountDeletionView.as_view(), name="manager-account-deletion"),
]
