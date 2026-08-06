from django.apps import apps
from django.db.models.signals import post_migrate
from django.dispatch import receiver

from core.services.reference_data_bootstrap import ensure_reference_data


@receiver(post_migrate)
def ensure_core_reference_data(sender, app_config=None, **kwargs):
    if app_config is None or app_config.label != "core":
        return
    if not apps.is_installed("core"):
        return
    ensure_reference_data()
