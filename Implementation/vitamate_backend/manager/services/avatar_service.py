from __future__ import annotations

from uuid import uuid4

from django.conf import settings
from django.core.files.storage import default_storage
from rest_framework import serializers

from users.services.user_profile_service import UserProfileService


class AvatarService:
    MAX_BYTES = 5 * 1024 * 1024
    SIGNATURES = (
        (b"\xff\xd8\xff", "jpg"),
        (b"\x89PNG\r\n\x1a\n", "png"),
        (b"GIF87a", "gif"),
        (b"GIF89a", "gif"),
    )

    @classmethod
    def validate_uploaded_file(cls, uploaded_file):
        if uploaded_file.size <= 0:
            raise serializers.ValidationError("Avatar file is empty.")
        if uploaded_file.size > cls.MAX_BYTES:
            raise serializers.ValidationError("Avatar must be 5 MB or smaller.")

        position = uploaded_file.tell() if hasattr(uploaded_file, "tell") else 0
        header = uploaded_file.read(16)
        if hasattr(uploaded_file, "seek"):
            uploaded_file.seek(position)

        for signature, extension in cls.SIGNATURES:
            if header.startswith(signature):
                return extension
        if header.startswith(b"RIFF") and header[8:12] == b"WEBP":
            return "webp"
        raise serializers.ValidationError("Avatar must be a PNG, JPG, GIF, or WebP image.")

    @classmethod
    def replace_avatar(cls, *, user, uploaded_file) -> str:
        extension = cls.validate_uploaded_file(uploaded_file)
        profile = UserProfileService.ensure_profile(user)
        cls.delete_avatar_file(avatar_url=getattr(profile, "avatar_url", ""))

        path = f"avatars/user_{user.id}/{uuid4().hex}.{extension}"
        if hasattr(uploaded_file, "seek"):
            uploaded_file.seek(0)
        saved_path = default_storage.save(path, uploaded_file)
        avatar_url = default_storage.url(saved_path)

        profile.avatar_url = avatar_url
        profile.save(update_fields=["avatar_url"])
        return avatar_url

    @classmethod
    def clear_avatar(cls, *, user) -> None:
        profile = UserProfileService.ensure_profile(user)
        cls.delete_avatar_file(avatar_url=getattr(profile, "avatar_url", ""))
        profile.avatar_url = ""
        profile.save(update_fields=["avatar_url"])

    @staticmethod
    def delete_avatar_file(*, avatar_url: str) -> None:
        if not avatar_url:
            return
        media_url = str(settings.MEDIA_URL or "/media/")
        if not avatar_url.startswith(media_url):
            return
        relative_path = avatar_url[len(media_url):].lstrip("/")
        if relative_path:
            default_storage.delete(relative_path)
