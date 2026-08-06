from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers

from manager.services.avatar_service import AvatarService


class HealthGoalPatchSerializer(serializers.Serializer):
    custom_value = serializers.FloatField(required=False, allow_null=True)


class AccountDeletionSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, max_length=240)


class AvatarUploadSerializer(serializers.Serializer):
    avatar = serializers.FileField()

    def validate_avatar(self, value):
        AvatarService.validate_uploaded_file(value)
        return value


class PasswordChangeSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True, trim_whitespace=False)
    new_password = serializers.CharField(write_only=True, trim_whitespace=False)
    new_password_confirm = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate_current_password(self, value):
        user = self.context["user"]
        if not user.check_password(value):
            raise serializers.ValidationError("Current password is incorrect.")
        return value

    def validate(self, attrs):
        if attrs["new_password"] != attrs["new_password_confirm"]:
            raise serializers.ValidationError(
                {"new_password_confirm": "New passwords do not match."}
            )
        try:
            validate_password(attrs["new_password"], user=self.context["user"])
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"new_password": list(exc.messages)})
        return attrs
