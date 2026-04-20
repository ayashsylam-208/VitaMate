from __future__ import annotations

from core.models import ConditionType, UserCondition


class ConditionCatalogService:
    SUPPORTED_SLUGS = ("diabetes", "hypertension", "dyslipidemia")
    CANONICAL_ALIAS_MAP = {
        "diabetes": "diabetes",
        "hypertension": "hypertension",
        "dyslipidemia": "dyslipidemia",
        "hyperlipidemia": "dyslipidemia",
    }

    @classmethod
    def canonical_slug(cls, condition_type: ConditionType | None) -> str:
        if condition_type is None:
            return ""
        candidates = [
            getattr(condition_type, "slug", ""),
            getattr(condition_type, "code", ""),
            getattr(condition_type, "name", ""),
        ]
        for candidate in candidates:
            slug = cls.CANONICAL_ALIAS_MAP.get(str(candidate).strip().lower())
            if slug:
                return slug
        return str(getattr(condition_type, "slug", "") or getattr(condition_type, "code", "")).strip().lower()

    @classmethod
    def display_name(cls, condition_type: ConditionType) -> str:
        return condition_type.display_name or condition_type.name

    @classmethod
    def supported_queryset(cls):
        return ConditionType.objects.filter(is_supported=True).order_by("sort_order", "display_name", "name")

    @classmethod
    def resolve_supported_condition_type(cls, *, condition_type_id: int | None = None, slug: str | None = None) -> ConditionType:
        queryset = cls.supported_queryset()
        if condition_type_id is not None:
            return queryset.get(pk=condition_type_id)

        if slug:
            canonical = cls.CANONICAL_ALIAS_MAP.get(slug.strip().lower(), slug.strip().lower())
            return queryset.filter(slug=canonical).first() or queryset.get(code=canonical)

        raise ConditionType.DoesNotExist("A supported chronic condition type is required.")

    @classmethod
    def is_supported(cls, condition_type: ConditionType) -> bool:
        return bool(condition_type.is_supported and cls.canonical_slug(condition_type) in cls.SUPPORTED_SLUGS)

    @classmethod
    def measurement_types(cls, condition_type: ConditionType) -> list[str]:
        schema = condition_type.setup_schema or {}
        measurement_types = schema.get("measurement_types") or []
        return [str(value) for value in measurement_types]

    @classmethod
    def setup_fields(cls, condition_type: ConditionType) -> list[dict]:
        schema = condition_type.setup_schema or {}
        fields = schema.get("setup_fields") or []
        return [dict(item) for item in fields if isinstance(item, dict)]

    @classmethod
    def supports_direct_daily_reading(cls, condition_type: ConditionType) -> bool:
        schema = condition_type.setup_schema or {}
        return bool(schema.get("supports_direct_daily_reading"))

    @classmethod
    def profile_defaults(cls, condition_type: ConditionType) -> dict:
        schema = condition_type.setup_schema or {}
        defaults = schema.get("profile_defaults") or {}
        return dict(defaults)

    @classmethod
    def normalize_profile_data(cls, *, condition_type: ConditionType, profile_data: dict | None) -> dict:
        normalized = cls.profile_defaults(condition_type)
        incoming = profile_data or {}
        normalized.update({str(key): value for key, value in incoming.items()})
        return normalized

    @classmethod
    def validate_profile_data(cls, *, condition_type: ConditionType, profile_data: dict) -> None:
        missing = []
        for field in cls.setup_fields(condition_type):
            if not field.get("required"):
                continue
            key = field.get("key")
            value = profile_data.get(key)
            if value in (None, ""):
                missing.append(key)
        if missing:
            raise ValueError(f"Missing required setup fields: {', '.join(missing)}")

    @classmethod
    def supported_condition_payloads(cls, *, user) -> list[dict]:
        active_condition_ids = set(
            UserCondition.objects.filter(
                user=user,
                is_active=True,
                status__in=(
                    UserCondition.STATUS_ACTIVE,
                    UserCondition.STATUS_CONTROLLED,
                    UserCondition.STATUS_NEEDS_ATTENTION,
                ),
            ).values_list("condition_type_id", flat=True)
        )
        payloads = []
        for item in cls.supported_queryset():
            is_active = item.id in active_condition_ids
            payloads.append(
                {
                    "id": item.id,
                    "code": item.code,
                    "slug": item.slug,
                    "name": item.name,
                    "display_name": cls.display_name(item),
                    "description": item.description,
                    "can_add": not is_active,
                    "is_active_for_user": is_active,
                    "severity_options": list(item.severity_options or []),
                    "setup_fields": cls.setup_fields(item),
                    "measurement_types": cls.measurement_types(item),
                    "supports_direct_daily_reading": cls.supports_direct_daily_reading(item),
                }
            )
        return payloads
